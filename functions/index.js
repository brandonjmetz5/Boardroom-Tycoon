const {onRequest} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onDocumentCreated, onDocumentDeleted, onDocumentUpdated} = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();

// MARK: - Public chat retention (paths match iOS ChatService: publicChats/{room}/messages)

/** Document IDs under `publicChats` that receive scheduled pruning. */
const PUBLIC_CHAT_ROOM_IDS = ["general", "sales", "help"];

/** Messages with createdAt older than this many days are deleted by purgePublicChatMessages (aligns with 24h client window + daily job). */
const PUBLIC_CHAT_RETENTION_DAYS = 1;

/** Firestore batch limit is 500; stay under it. */
const PUBLIC_CHAT_DELETE_BATCH = 450;

/** Safety cap on inner delete loops per room per invocation (avoids runaway timeouts). */
const PUBLIC_CHAT_MAX_ROUNDS_PER_ROOM = 40;

// MARK: - CPU Market Minions config

const CPU_USER_ID = "CPU";
const CPU_DISPLAY_NAME = "Market Board";
const FEE_PERCENT = 3.0;

// MARK: - Stocks (player-driven, tick-updated)

// Only 6 stocks in v1: raw resources only.
const STOCKS = [
  {symbol: "GLD", name: "Gold", resourceIDs: ["raw-gold"]},
  {symbol: "DMD", name: "Diamond", resourceIDs: ["raw-diamonds"]},
  // Note: iOS production currently uses "crude-oil" inventory doc IDs; accept both.
  {symbol: "OIL", name: "Oil", resourceIDs: ["raw-oil", "crude-oil"]},
  {symbol: "SLV", name: "Silver", resourceIDs: ["raw-silver"]},
  {symbol: "CL", name: "Coal", resourceIDs: ["raw-coal"]},
  {symbol: "IRN", name: "Iron", resourceIDs: ["raw-iron"]},
];
const DEFAULT_TOTAL_SHARES = 1000000;
const DEFAULT_MAX_OWNERSHIP_PERCENT = 0.25;

const RESOURCE_ID_TO_SYMBOL = (() => {
  const map = {};
  for (const s of STOCKS) {
    for (const rid of (s.resourceIDs || [])) map[rid] = s.symbol;
  }
  return map;
})();

function stockRef(symbol) {
  return db.collection("stockSymbols").doc(symbol);
}

function stockSignalsRef() {
  return db.collection("worldState").doc("stockSignals");
}

async function ensureStocksInitialized() {
  const batch = db.batch();
  const now = admin.firestore.Timestamp.now();

  for (const s of STOCKS) {
    const ref = stockRef(s.symbol);
    batch.set(
      ref,
      {
        id: s.symbol,
        symbol: s.symbol,
        name: s.name,
        // If already exists, keep existing price; otherwise seed from anchor where possible.
        // prevPrice used to compute change each tick.
        currentPrice: admin.firestore.FieldValue.increment(0),
        prevPrice: admin.firestore.FieldValue.increment(0),
        priceChange: admin.firestore.FieldValue.increment(0),
        lastUpdatedAt: now,
        totalShares: DEFAULT_TOTAL_SHARES,
        maxOwnershipPercent: DEFAULT_MAX_OWNERSHIP_PERCENT,
      },
      {merge: true},
    );
  }

  // Ensure the signals doc exists (counters get incremented by triggers).
  batch.set(
    stockSignalsRef(),
    {
      tickId: 0,
      windowStartedAt: now,
      lastUpdatedAt: now,
      // nested maps will be created on first increment
    },
    {merge: true},
  );

  await batch.commit();
}

// (reserved) history window helper; not used in tick yet.

function clamp(n, lo, hi) {
  return Math.max(lo, Math.min(hi, n));
}

function safeNum(n) {
  const x = Number(n || 0);
  return Number.isFinite(x) ? x : 0;
}

function pctMoveFromSignals({demandNotional, supplyUnits, buyNotional}) {
  // Balanced: players can move price within a session, but bounded per tick.
  // Demand proxy: notional of filled listing buys + notional of filled buy orders.
  // Supply proxy: production units collected.
  const demand = safeNum(demandNotional) + safeNum(buyNotional);
  const supply = safeNum(supplyUnits);

  // Smooth non-linear response.
  const demandTerm = Math.log1p(demand / 50000); // damped for high-volume servers
  const supplyTerm = Math.log1p(supply / 1500); // damped for high-volume servers

  const raw = 0.0045 * demandTerm - 0.0042 * supplyTerm;
  return clamp(raw, -0.005, 0.005); // +/- 0.5% per tick cap
}

function readSignal(signals, groupName, sym) {
  // Firestore may return dotted-field-path increments either as nested maps or as flat keys.
  // Support both shapes to keep tick math robust.
  const nested = signals[groupName];
  if (nested && typeof nested === "object" && nested[sym] !== undefined) return nested[sym];
  const flatKey = `${groupName}.${sym}`;
  if (signals[flatKey] !== undefined) return signals[flatKey];
  return 0;
}

// MARK: - Stock signals: Firestore triggers

function symbolForResourceID(resourceID) {
  return RESOURCE_ID_TO_SYMBOL[String(resourceID || "")];
}

async function bumpSignal(path, value) {
  const now = admin.firestore.Timestamp.now();
  await stockSignalsRef().set(
    {
      lastUpdatedAt: now,
      [path]: admin.firestore.FieldValue.increment(value),
    },
    {merge: true},
  );
}

// Resource Market fills: count only documents that were marked sold before delete.
exports.onMarketListingDeleted = onDocumentDeleted("marketListings/{listingId}", async (event) => {
  const data = event.data ? event.data.data() : null;
  if (!data) return;

  // Only count true fills; if soldAt transition already counted this listing, skip.
  if (!data.soldAt || !!data.cancelledAt) return;
  if (data.stockSignalCountedAt) return;

  const rid = data.resourceID || data.itemID;
  const sym = symbolForResourceID(rid);
  if (!sym) return;

  const qty = safeNum(data.quantity);
  const ppu = safeNum(data.pricePerUnit);
  if (qty <= 0 || ppu <= 0) return;

  await Promise.all([
    bumpSignal(`resourceTradeUnits.${sym}`, qty),
    bumpSignal(`resourceTradeNotional.${sym}`, qty * ppu),
  ]);
});

// Resource Market fills (robust): count when soldAt is written, before the delete happens.
exports.onMarketListingSoldAtWritten = onDocumentUpdated("marketListings/{listingId}", async (event) => {
  const before = (event.data && event.data.before) ? event.data.before.data() : null;
  const after = (event.data && event.data.after) ? event.data.after.data() : null;
  if (!after || !before) return;

  const beforeHadSoldAt = !!before.soldAt;
  const afterHasSoldAt = !!after.soldAt;
  const afterHasCancelledAt = !!after.cancelledAt;

  if (beforeHadSoldAt) return; // only count on the transition
  if (!afterHasSoldAt) return;
  if (afterHasCancelledAt) return; // safety

  const rid = after.resourceID || after.itemID;
  const sym = symbolForResourceID(rid);
  if (!sym) return;

  const qty = safeNum(after.quantity);
  const ppu = safeNum(after.pricePerUnit);
  if (qty <= 0 || ppu <= 0) return;

  await Promise.all([
    bumpSignal(`resourceTradeUnits.${sym}`, qty),
    bumpSignal(`resourceTradeNotional.${sym}`, qty * ppu),
    event.data.after.ref.set({stockSignalCountedAt: admin.firestore.Timestamp.now()}, {merge: true}),
  ]);
});

// Buy Order fulfillment: count order when status changes open -> filled.
exports.onBuyOrderFilled = onDocumentUpdated("marketBuyOrders/{orderId}", async (event) => {
  const before = (event.data && event.data.before) ? event.data.before.data() : {};
  const after = (event.data && event.data.after) ? event.data.after.data() : {};
  if ((before.status || "") === "filled") return;
  if ((after.status || "") !== "filled") return;

  const buyerUserID = after.buyerUserID || "";
  if (!buyerUserID || buyerUserID === CPU_USER_ID) return; // player-driven only

  const lines = Array.isArray(after.lines) ? after.lines : [];
  const totalPrice = safeNum(after.totalPrice);
  const totalQty = lines.reduce((sum, l) => sum + safeNum(l.quantity), 0);
  if (totalPrice <= 0 || totalQty <= 0) return;

  const ppu = totalPrice / totalQty;
  const tasks = [];
  for (const line of lines) {
    const rid = line.resourceID;
    const sym = symbolForResourceID(rid);
    if (!sym) continue;
    const qty = safeNum(line.quantity);
    if (qty <= 0) continue;
    tasks.push(bumpSignal(`buyOrderUnits.${sym}`, qty));
    tasks.push(bumpSignal(`buyOrderNotional.${sym}`, qty * ppu));
  }
  if (tasks.length > 0) await Promise.all(tasks);
});

// Production collect: create a production event doc in player space; trigger increments supply for the stock.
exports.onProductionEventCreated = onDocumentCreated("playerProfiles/{userId}/productionEvents/{eventId}", async (event) => {
  const data = event.data ? event.data.data() : null;
  if (!data) return;

  const uid = event.params.userId;
  if (!uid || uid === CPU_USER_ID) return;

  const rid = data.resourceID || data.itemID;
  const sym = symbolForResourceID(rid);
  if (!sym) return;

  const qty = safeNum(data.quantity);
  if (qty <= 0) return;

  await bumpSignal(`productionUnits.${sym}`, qty);
});

async function bumpFromStockPositionDelta(userID, symbol, deltaShares) {
  if (!userID || userID === CPU_USER_ID) return;
  const sym = String(symbol || "").toUpperCase();
  if (!sym || !deltaShares) return;

  const snap = await stockRef(sym).get();
  const price = safeNum((snap.data() || {}).currentPrice);
  if (price <= 0) return;

  const notional = Math.abs(deltaShares) * price;
  if (deltaShares > 0) {
    await bumpSignal(`stockTradeBuyNotional.${sym}`, notional);
  } else {
    await bumpSignal(`stockTradeSellNotional.${sym}`, notional);
  }
}

exports.onStockPositionCreated = onDocumentCreated("playerProfiles/{userId}/stockPositions/{symbol}", async (event) => {
  const data = event.data ? event.data.data() : {};
  const shares = safeNum(data.sharesOwned);
  if (shares <= 0) return;
  await bumpFromStockPositionDelta(event.params.userId, event.params.symbol, shares);
});

exports.onStockPositionUpdated = onDocumentUpdated("playerProfiles/{userId}/stockPositions/{symbol}", async (event) => {
  const before = (event.data && event.data.before) ? event.data.before.data() : {};
  const after = (event.data && event.data.after) ? event.data.after.data() : {};
  const beforeShares = safeNum(before.sharesOwned);
  const afterShares = safeNum(after.sharesOwned);
  const deltaShares = afterShares - beforeShares;
  if (!deltaShares) return;
  await bumpFromStockPositionDelta(event.params.userId, event.params.symbol, deltaShares);
});

exports.onStockPositionDeleted = onDocumentDeleted("playerProfiles/{userId}/stockPositions/{symbol}", async (event) => {
  const data = event.data ? event.data.data() : {};
  const shares = safeNum(data.sharesOwned);
  if (shares <= 0) return;
  await bumpFromStockPositionDelta(event.params.userId, event.params.symbol, -shares);
});

// Tradeable items (mirrors iOS MarketCatalog.tradeableItems()).
// If you add tradeable items in-app, add them here too.
const TRADEABLE_ITEMS = [
  {id: "raw-gold", name: "Raw Gold", category: "Raw Material", isFractional: false},
  {id: "raw-silver", name: "Raw Silver", category: "Raw Material", isFractional: false},
  {id: "raw-diamonds", name: "Raw Diamonds", category: "Raw Material", isFractional: false},
  {id: "raw-oil", name: "Crude Oil", category: "Raw Material", isFractional: false},
  {id: "raw-coal", name: "Raw Coal", category: "Raw Material", isFractional: false},
  {id: "raw-iron", name: "Raw Iron", category: "Raw Material", isFractional: false},
  {id: "raw-stone", name: "Raw Stone", category: "Raw Material", isFractional: false},
  {id: "gold-bar", name: "Gold Bar", category: "Refined Material", isFractional: true},
  {id: "cut-diamond", name: "Cut Diamond", category: "Refined Material", isFractional: false},
  {id: "steel", name: "Steel", category: "Refined Material", isFractional: false},
  {id: "silver-bar", name: "Silver Bar", category: "Refined Material", isFractional: false},
  {id: "diamond-dust", name: "Diamond Dust", category: "Refined Material", isFractional: false},
  {id: "microchip", name: "Microchip", category: "Refined Material", isFractional: false},
  {id: "heat-sink", name: "Heat Sink", category: "Refined Material", isFractional: false},
  {id: "processed-coal", name: "Processed Coal", category: "Refined Material", isFractional: false},
  {id: "gasoline", name: "Gasoline", category: "Refined Material", isFractional: false},
  {id: "diesel", name: "Diesel", category: "Refined Material", isFractional: false},
  {id: "iron-bars", name: "Iron Bars", category: "Refined Material", isFractional: false},
  {id: "industrial-heat-blocks", name: "Industrial Heat Blocks", category: "Refined Material", isFractional: false},
  {id: "fuel-cell", name: "Fuel Cells", category: "Fuel", isFractional: false},
  {id: "machinery-fuel-pack", name: "Machinery Fuel Packs", category: "Fuel", isFractional: false},
  {id: "brick", name: "Brick", category: "Building Material", isFractional: false},
  {id: "concrete-mix", name: "Concrete Mix", category: "Building Material", isFractional: false},
  {id: "glass", name: "Glass", category: "Building Material", isFractional: false},
  {id: "steel-beams", name: "Steel Beams", category: "Building Material", isFractional: false},
  {id: "machine-gear", name: "Machine Gear", category: "Component", isFractional: false},
  {id: "robotic-machine-arms", name: "Robotic Machine Arms", category: "Component", isFractional: false},
  {id: "gold-ring", name: "Gold Ring", category: "Luxury Good", isFractional: false},
  {id: "gold-watch", name: "Gold Watch", category: "Luxury Good", isFractional: false},
  {id: "silver-ring", name: "Silver Ring", category: "Luxury Good", isFractional: false},
  {id: "silver-watch", name: "Silver Watch", category: "Luxury Good", isFractional: false},
  {id: "luxury-ring", name: "Luxury Ring", category: "Luxury Good", isFractional: false},
  {id: "luxury-watch", name: "Luxury Watch", category: "Luxury Good", isFractional: false},
];

// Fallback “anchor” prices (mirrors ItemValueCatalog.unitPrice()).
const ANCHOR_PRICE = {
  "fuel-cell": 8.0,
  "raw-gold": 42.0,
  "raw-silver": 0.65,
  "raw-diamonds": 120.0,
  "raw-oil": 0.85,
  "raw-coal": 0.12,
  "raw-iron": 0.08,
  "raw-stone": 0.02,
  "gold-bar": 1850.0,
  "cut-diamond": 450.0,
  "steel": 0.35,
  "silver-bar": 22.0,
  "diamond-dust": 85.0,
  "microchip": 120.0,
  "heat-sink": 45.0,
  "brick": 1.2,
  "concrete-mix": 2.5,
  "glass": 3.0,
  "gold-ring": 4200.0,
  "gold-watch": 5500.0,
  "silver-ring": 55.0,
  "silver-watch": 85.0,
  "luxury-ring": 8000.0,
  "luxury-watch": 12000.0,
  "processed-coal": 0.35,
  "gasoline": 2.8,
  "diesel": 2.6,
  "iron-bars": 1.5,
  "steel-beams": 8.0,
  "machine-gear": 95.0,
  "robotic-machine-arms": 450.0,
  "machinery-fuel-pack": 25.0,
  "industrial-heat-blocks": 12.0,
};

const QUALITIES = [1, 2, 3, 4, 5];

// Supply targets per item, per quality.
const MIN_LISTING_COUNT = {1: 6, 2: 4, 3: 3, 4: 2, 5: 1};
const MIN_TOTAL_UNITS = {1: 600, 2: 300, 3: 150, 4: 75, 5: 30};

// Demand (buy order) targets per item, per quality.
const MIN_CPU_BUY_ORDER_COUNT = {1: 2, 2: 1, 3: 1, 4: 0, 5: 0};
const TARGET_CPU_BUY_UNITS = {1: 500, 2: 200, 3: 75, 4: 0, 5: 0};

// Pricing bands: referencePrice * [low, high]
const SELL_BAND = {
  1: [0.95, 1.10],
  2: [1.00, 1.20],
  3: [1.05, 1.30],
  4: [1.10, 1.45],
  5: [1.15, 1.60],
};
const BUY_BAND = {
  1: [0.55, 0.70],
  2: [0.60, 0.75],
  3: [0.65, 0.80],
};

// Hybrid pricing: use median listing price if enough data; otherwise use anchor.
const MIN_LISTINGS_FOR_MEDIAN = 5;

// Per-tick caps (global).
const MAX_NEW_CPU_LISTINGS_PER_TICK = 50;
const MAX_CPU_UNITS_LISTED_PER_TICK = 10000;
const MAX_DISTINCT_ITEMS_TO_TOUCH_PER_TICK = 30;
const MAX_NEW_CPU_BUY_ORDERS_PER_TICK = 40;
const MAX_CPU_ESCROW_SPEND_PER_TICK = 50000;

function clampMin1(n) {
  return Math.max(1, n);
}

function median(values) {
  if (!values || values.length === 0) return null;
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  if (sorted.length % 2 === 0) return (sorted[mid - 1] + sorted[mid]) / 2;
  return sorted[mid];
}

function randomBetween(low, high) {
  return low + Math.random() * (high - low);
}

function bucketKey(resourceID, quality) {
  return `${resourceID}__q${quality}`;
}

async function ensureCpuProfile() {
  const cpuRef = db.collection("playerProfiles").doc(CPU_USER_ID);
  await cpuRef.set(
    {
      id: CPU_USER_ID,
      cash: 1000000000,
      level: 1,
      xp: 0,
      buildingSlotCount: 0,
      starterMineClaimed: true,
      researchPoints: 0,
      createdAt: admin.firestore.Timestamp.now(),
      isCPU: true,
      displayName: CPU_DISPLAY_NAME,
    },
    {merge: true},
  );
}

function computeReferencePrice(resourceID, quality, listingsInBucket) {
  const prices = (listingsInBucket || [])
    .map((l) => l.pricePerUnit)
    .filter((p) => typeof p === "number" && p > 0);

  if (prices.length >= MIN_LISTINGS_FOR_MEDIAN) {
    return median(prices);
  }

  const anchor = ANCHOR_PRICE[resourceID];
  if (typeof anchor === "number" && anchor > 0) return anchor;
  return null;
}

async function fetchAllResourceListings() {
  const snap = await db.collection("marketListings").get();
  return snap.docs
    .map((d) => ({docID: d.id, ...d.data()}))
    .filter((x) => ((x.quantity || 0) > 0))
    .map((x) => ({
      id: x.id || x.docID,
      sellerUserID: x.sellerUserID || "",
      resourceID: x.resourceID || x.itemID || "",
      resourceName: x.resourceName || x.itemName || "",
      resourceCategory: x.resourceCategory || x.category || "",
      quality: clampMin1(Number(x.quality || 1)),
      quantity: Number(x.quantity || 0),
      pricePerUnit: Number(x.pricePerUnit || 0),
      isFractional: Boolean(x.isFractional),
      isCPU: Boolean(x.isCPU),
    }));
}

async function fetchOpenBuyOrders() {
  const snap = await db.collection("marketBuyOrders").where("status", "==", "open").get();
  return snap.docs.map((d) => ({docID: d.id, ...d.data()}));
}

async function updateMarketAggregates(allListings, openOrders) {
  const aggregates = new Map(); // key: `${resourceID}__q${quality}` -> {resourceID, resourceName, quality, listingSum, listingQty, buySum, buyQty}

  // Listings: average listing price per unit for active listings.
  for (const l of allListings) {
    const key = bucketKey(l.resourceID, l.quality);
    if (!aggregates.has(key)) {
      aggregates.set(key, {
        resourceID: l.resourceID,
        resourceName: l.resourceName,
        quality: l.quality,
        listingSum: 0,
        listingQty: 0,
        buySum: 0,
        buyQty: 0,
      });
    }
    const agg = aggregates.get(key);
    agg.listingSum += (l.pricePerUnit || 0) * (l.quantity || 0);
    agg.listingQty += (l.quantity || 0);
  }

  // Buy orders: effective price per unit from open buy orders (using lines and totalPrice).
  for (const o of openOrders) {
    const lines = Array.isArray(o.lines) ? o.lines : [];
    const totalPrice = Number(o.totalPrice || 0);
    let totalQty = 0;
    for (const line of lines) {
      totalQty += Number(line.quantity || 0);
    }
    if (totalPrice <= 0 || totalQty <= 0) continue;

    const ppu = totalPrice / totalQty;

    for (const line of lines) {
      const rid = line.resourceID;
      const name = line.resourceName;
      const q = clampMin1(Number(line.resourceQuality || 1));
      const qty = Number(line.quantity || 0);
      if (!rid || qty <= 0) continue;

      const key = bucketKey(rid, q);
      if (!aggregates.has(key)) {
        aggregates.set(key, {
          resourceID: rid,
          resourceName: name,
          quality: q,
          listingSum: 0,
          listingQty: 0,
          buySum: 0,
          buyQty: 0,
        });
      }
      const agg = aggregates.get(key);
      agg.buySum += ppu * qty;
      agg.buyQty += qty;
    }
  }

  const batch = db.batch();
  const nowTs = admin.firestore.Timestamp.now();

  for (const [key, agg] of aggregates.entries()) {
    const parts = key.split("__q");
    const resourceID = parts[0];
    const quality = Number(parts[1] || agg.quality || 1);

    const avgListingPrice =
      agg.listingQty > 0 ? Number((agg.listingSum / agg.listingQty).toFixed(4)) : null;
    const avgBuyOrderPrice =
      agg.buyQty > 0 ? Number((agg.buySum / agg.buyQty).toFixed(4)) : null;

    const docRef = db.collection("marketAggregates").doc(key);
    batch.set(
      docRef,
      {
        id: key,
        resourceID,
        resourceName: agg.resourceName || "",
        quality,
        avgListingPrice,
        avgBuyOrderPrice,
        listingVolumeUnits: agg.listingQty,
        buyVolumeUnits: agg.buyQty,
        lastUpdatedAt: nowTs,
      },
      {merge: true},
    );
  }

  if (aggregates.size > 0) {
    await batch.commit();
  }
}

async function ensureCpuSellSupply(allListings) {
  const byBucket = new Map();
  for (const l of allListings) {
    const key = bucketKey(l.resourceID, l.quality);
    if (!byBucket.has(key)) byBucket.set(key, []);
    byBucket.get(key).push(l);
  }

  let createdCount = 0;
  let unitsAdded = 0;
  let itemsTouched = 0;
  const touchedItems = new Set();

  const batch = db.batch();

  for (const item of TRADEABLE_ITEMS) {
    if (itemsTouched >= MAX_DISTINCT_ITEMS_TO_TOUCH_PER_TICK) break;
    let touchedThisItem = false;

    for (const q of QUALITIES) {
      if (createdCount >= MAX_NEW_CPU_LISTINGS_PER_TICK) break;
      if (unitsAdded >= MAX_CPU_UNITS_LISTED_PER_TICK) break;

      const key = bucketKey(item.id, q);
      const existing = byBucket.get(key) || [];
      const existingCount = existing.length;
      const existingQty = existing.reduce((sum, x) => sum + (x.quantity || 0), 0);

      const minCount = MIN_LISTING_COUNT[q];
      const minQty = MIN_TOTAL_UNITS[q];

      const needCount = Math.max(0, minCount - existingCount);
      const needQty = Math.max(0, minQty - existingQty);

      if (needCount <= 0 && needQty <= 0) continue;

      const ref = computeReferencePrice(item.id, q, existing);
      if (!ref) continue;

      const [lowMult, highMult] = SELL_BAND[q];
      const perListingQtyTarget = Math.max(1, Math.ceil(minQty / minCount));
      let remainingCount = needCount;
      let remainingQty = needQty;

      // Even if count is ok but qty is low, we still add at least 1 listing (subject to caps).
      if (remainingCount === 0 && remainingQty > 0) remainingCount = 1;

      while (remainingCount > 0 || remainingQty > 0) {
        if (createdCount >= MAX_NEW_CPU_LISTINGS_PER_TICK) break;
        if (unitsAdded >= MAX_CPU_UNITS_LISTED_PER_TICK) break;

        const listingQty = Math.min(
          perListingQtyTarget,
          Math.max(1, remainingQty || perListingQtyTarget),
          MAX_CPU_UNITS_LISTED_PER_TICK - unitsAdded,
        );

        const price = ref * randomBetween(lowMult, highMult);
        const listingRef = db.collection("marketListings").doc();
        batch.set(listingRef, {
          id: listingRef.id,
          sellerUserID: CPU_USER_ID,
          sellerName: CPU_DISPLAY_NAME,
          resourceID: item.id,
          resourceName: item.name,
          resourceCategory: item.category,
          quality: q,
          quantity: listingQty,
          pricePerUnit: Number(price.toFixed(4)),
          isFractional: item.isFractional,
          createdAt: admin.firestore.Timestamp.now(),
          isCPU: true,
          cpuReason: "liquidity_topup",
        });

        createdCount += 1;
        unitsAdded += listingQty;
        remainingCount = Math.max(0, remainingCount - 1);
        remainingQty = Math.max(0, remainingQty - listingQty);
        touchedThisItem = true;

        if (remainingCount <= 0 && remainingQty <= 0) break;
      }
    }

    if (touchedThisItem && !touchedItems.has(item.id)) {
      touchedItems.add(item.id);
      itemsTouched += 1;
    }
  }

  if (createdCount > 0) {
    await batch.commit();
  }

  return {createdCount, unitsAdded, itemsTouched};
}

async function ensureCpuBuyOrders(openOrders, allListings) {
  // Aggregate CPU open buy orders by item+quality (count and open units).
  const cpuBuckets = new Map(); // key -> {count, units}
  for (const o of openOrders) {
    const buyer = o.buyerUserID || "";
    if (buyer !== CPU_USER_ID) continue;
    const lines = Array.isArray(o.lines) ? o.lines : [];
    for (const line of lines) {
      const rid = line.resourceID;
      const q = clampMin1(Number(line.resourceQuality || 1));
      const qty = Number(line.quantity || 0);
      const key = bucketKey(rid, q);
      const existing = cpuBuckets.get(key) || {count: 0, units: 0};
      existing.count += 1;
      existing.units += qty;
      cpuBuckets.set(key, existing);
    }
  }

  // For pricing we want listing buckets too (for median).
  const listingBuckets = new Map();
  for (const l of allListings) {
    const key = bucketKey(l.resourceID, l.quality);
    if (!listingBuckets.has(key)) listingBuckets.set(key, []);
    listingBuckets.get(key).push(l);
  }

  let createdOrders = 0;
  let escrowSpent = 0;

  const cpuProfileRef = db.collection("playerProfiles").doc(CPU_USER_ID);
  const batch = db.batch();

  for (const item of TRADEABLE_ITEMS) {
    for (const q of QUALITIES) {
      const minOrders = MIN_CPU_BUY_ORDER_COUNT[q] || 0;
      const targetUnits = TARGET_CPU_BUY_UNITS[q] || 0;
      if (minOrders <= 0 && targetUnits <= 0) continue;
      if (!BUY_BAND[q]) continue;

      if (createdOrders >= MAX_NEW_CPU_BUY_ORDERS_PER_TICK) break;
      if (escrowSpent >= MAX_CPU_ESCROW_SPEND_PER_TICK) break;

      const key = bucketKey(item.id, q);
      const existing = cpuBuckets.get(key) || {count: 0, units: 0};
      const needOrders = Math.max(0, minOrders - existing.count);
      const needUnits = Math.max(0, targetUnits - existing.units);

      if (needOrders <= 0 && needUnits <= 0) continue;

      const ref = computeReferencePrice(item.id, q, listingBuckets.get(key) || []);
      if (!ref) continue;
      const [lowMult, highMult] = BUY_BAND[q];

      // Create enough orders to reach minOrders; size them to reach targetUnits.
      const ordersToCreate = Math.max(needOrders, needUnits > 0 ? 1 : 0);
      const perOrderUnits = Math.max(1, Math.ceil(targetUnits / Math.max(1, minOrders)));
      let remainingUnits = needUnits;
      let remainingOrders = ordersToCreate;

      while (remainingOrders > 0) {
        if (createdOrders >= MAX_NEW_CPU_BUY_ORDERS_PER_TICK) break;
        if (escrowSpent >= MAX_CPU_ESCROW_SPEND_PER_TICK) break;

        // Mix in some multi-line CPU buy orders so players see variety.
        const makeMulti = Math.random() < 0.22; // ~22% of CPU orders become 2-line contracts

        const units1 = Math.max(1, remainingUnits > 0 ? Math.min(perOrderUnits, remainingUnits) : perOrderUnits);
        const ppu1 = ref * randomBetween(lowMult, highMult);
        const lines = [
          {
            resourceID: item.id,
            resourceName: item.name,
            resourceCategory: item.category,
            resourceQuality: q,
            quantity: units1,
            isFractional: item.isFractional,
          },
        ];

        let totalPrice = units1 * ppu1;

        if (makeMulti) {
          const candidates = TRADEABLE_ITEMS.filter((x) => x.id !== item.id);
          if (candidates.length > 0) {
            const pick = candidates[Math.floor(Math.random() * candidates.length)];
            const key2 = bucketKey(pick.id, q);
            const ref2 = computeReferencePrice(pick.id, q, listingBuckets.get(key2) || []);
            if (ref2) {
              const ppu2 = ref2 * randomBetween(lowMult, highMult);
              const units2 = Math.max(1, Math.ceil(units1 * randomBetween(0.15, 0.45)));
              totalPrice += units2 * ppu2;
              lines.push({
                resourceID: pick.id,
                resourceName: pick.name,
                resourceCategory: pick.category,
                resourceQuality: q,
                quantity: units2,
                isFractional: pick.isFractional,
              });
            }
          }
        }

        const remainingBudget = MAX_CPU_ESCROW_SPEND_PER_TICK - escrowSpent;
        if (totalPrice > remainingBudget) break;

        const orderRef = db.collection("marketBuyOrders").doc();
        const netToSeller = totalPrice * (1 - FEE_PERCENT / 100);
        batch.set(orderRef, {
          id: orderRef.id,
          buyerUserID: CPU_USER_ID,
          buyerName: CPU_DISPLAY_NAME,
          lines,
          totalPrice: Number(totalPrice.toFixed(4)),
          feePercent: FEE_PERCENT,
          netToSeller: Number(netToSeller.toFixed(4)),
          status: "open",
          createdAt: admin.firestore.Timestamp.now(),
          filledAt: null,
          filledByUserID: null,
          isCPU: true,
          cpuReason: "floor_bid",
        });

        // Escrow spend: deduct from CPU profile cash (keeps this from inflating money supply).
        batch.set(cpuProfileRef, {cash: admin.firestore.FieldValue.increment(-totalPrice)}, {merge: true});

        createdOrders += 1;
        escrowSpent += totalPrice;
        remainingOrders -= 1;
        remainingUnits = Math.max(0, remainingUnits - units1);

        if (remainingOrders <= 0 && remainingUnits <= 0) break;
      }
    }
  }

  if (createdOrders > 0) {
    await batch.commit();
  }

  return {createdOrders, escrowSpent};
}

// Optional sample HTTP function
exports.helloWorld = onRequest((request, response) => {
  logger.info("Hello logs!", {structuredData: true});
  response.send("Hello from Firebase!");
});

// World tick: runs every 1 minute (60 seconds).
exports.worldTick = onSchedule("every 1 minutes", async (event) => {
  const now = new Date().toISOString();
  logger.info("worldTick fired", {at: now});

  // Heartbeat marker so you can verify ticks in Firestore even without logs.
  // Firestore path: worldState/worldTick
  const worldTickRef = db.collection("worldState").doc("worldTick");
  await worldTickRef.set(
    {
      lastTickAt: admin.firestore.Timestamp.now(),
      lastTickISO: now,
    },
    {merge: true},
  );

  // Concurrency guard: worldTick can overlap (max instances > 1). Overlap can reset
  // `worldState/stockSignals` before another instance reads it, resulting in pct=0.
  const lockId = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  const lockDurationMs = 90 * 1000; // should exceed typical tick runtime
  let shouldProceed = false;
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(worldTickRef);
    const data = snap.data() || {};
    const lockUntil = data.lockUntil;

    const nowMs = Date.now();
    const lockUntilMs =
      lockUntil && typeof lockUntil.toMillis === "function" ? lockUntil.toMillis() : 0;

    if (lockUntilMs > nowMs) {
      shouldProceed = false;
      return;
    }

    shouldProceed = true;
    tx.set(
      worldTickRef,
      {
        lockUntil: admin.firestore.Timestamp.fromMillis(nowMs + lockDurationMs),
        lockOwner: lockId,
        lockUpdatedAt: admin.firestore.Timestamp.now(),
      },
      {merge: true},
    );
  });

  if (!shouldProceed) {
    logger.info("worldTick skipped due to lock", {lockId});
    return null;
  }

  try {
    await ensureCpuProfile();
    await ensureStocksInitialized();

    const [listings, openOrders] = await Promise.all([
      fetchAllResourceListings(),
      fetchOpenBuyOrders(),
    ]);

    const sell = await ensureCpuSellSupply(listings);
    const buy = await ensureCpuBuyOrders(openOrders, listings);

    await updateMarketAggregates(listings, openOrders);

    // ---- Stocks: tick-driven price updates from player-driven signals ----
    const signalsSnap = await stockSignalsRef().get();
    const signals = signalsSnap.data() || {};

    const tickBatch = db.batch();
    const tickTs = admin.firestore.Timestamp.now();

    const refs = STOCKS.map((s) => stockRef(s.symbol));
    const snaps = await db.getAll(...refs);
    const bySymbol = new Map();
    for (const snap of snaps) {
      bySymbol.set(snap.id, snap);
    }

    for (const s of STOCKS) {
      const sym = s.symbol;
      const docRef = stockRef(sym);
      const stockSnap = bySymbol.get(sym);
      const data = stockSnap && stockSnap.exists ? (stockSnap.data() || {}) : {};
      const firstRid = (s.resourceIDs && s.resourceIDs.length > 0) ? s.resourceIDs[0] : null;
      const currentPrice = safeNum(data.currentPrice) || safeNum(ANCHOR_PRICE[firstRid]) || 10;
      const prevPrice = safeNum(data.prevPrice) || currentPrice;

      const demandNotional = safeNum(readSignal(signals, "resourceTradeNotional", sym));
      const buyNotional = safeNum(readSignal(signals, "buyOrderNotional", sym));
      const supplyUnits = safeNum(readSignal(signals, "productionUnits", sym));
      const stockBuyNotional = safeNum(readSignal(signals, "stockTradeBuyNotional", sym));
      const stockSellNotional = safeNum(readSignal(signals, "stockTradeSellNotional", sym));
      const effectiveStockBuyNotional = stockBuyNotional * 0.15;
      const effectiveStockSellNotional = stockSellNotional * 0.15;

      let pct = pctMoveFromSignals({
        demandNotional,
        buyNotional: buyNotional + effectiveStockBuyNotional,
        supplyUnits,
      });
      pct -= clamp(0.0012 * Math.log1p(effectiveStockSellNotional / 120000), 0, 0.0015);

      const anchor = safeNum(ANCHOR_PRICE[firstRid]) || currentPrice;
      const anchorGap = anchor > 0 ? (currentPrice - anchor) / anchor : 0;
      const meanReversion = clamp(-0.0007 * anchorGap, -0.0012, 0.0012);
      const inactivityDecay = (demandNotional + buyNotional + stockBuyNotional + stockSellNotional + supplyUnits) <= 0 ? -0.00035 : 0;
      pct = clamp(pct + meanReversion + inactivityDecay, -0.005, 0.005);

      const newPrice = Math.max(0.01, Number((currentPrice * (1 + pct)).toFixed(4)));
      const priceChange = Number((newPrice - prevPrice).toFixed(4));

      if (sym === "GLD") {
        logger.info("stockTickDebug.GL D", {
          sym,
          currentPrice,
          prevPrice,
          demandNotional,
          buyNotional,
          supplyUnits,
          stockBuyNotional,
          stockSellNotional,
          pct,
          newPrice,
          priceChange,
        });

        // Also write debug into Firestore so we can verify without relying on Logs UI.
        const dbgRef = db.collection("worldState").doc("stockTickDebug");
        tickBatch.set(
          dbgRef,
          {
            updatedAt: tickTs,
            sym: sym,
            demandNotional,
            buyNotional,
            supplyUnits,
            stockBuyNotional,
            stockSellNotional,
            pct: pct,
            currentPrice: currentPrice,
            prevPrice: prevPrice,
            newPrice: newPrice,
            priceChange: priceChange,
            tickSignals: {
              resourceTradeUnits: signals.resourceTradeUnits || {},
              buyOrderUnits: signals.buyOrderUnits || {},
              productionUnits: signals.productionUnits || {},
            },
          },
          {merge: true},
        );
      }

      tickBatch.set(
        docRef,
        {
          id: sym,
          symbol: sym,
          name: s.name,
          prevPrice: currentPrice,
          currentPrice: newPrice,
          priceChange,
          lastUpdatedAt: tickTs,
          totalShares: safeNum(data.totalShares) || DEFAULT_TOTAL_SHARES,
          maxOwnershipPercent: clamp(safeNum(data.maxOwnershipPercent) || DEFAULT_MAX_OWNERSHIP_PERCENT, 0.01, 1.0),
        },
        {merge: true},
      );

      // Append one history point per tick.
      const pointRef = docRef.collection("history").doc();
      tickBatch.set(pointRef, {
        id: pointRef.id,
        timestamp: tickTs,
        price: newPrice,
      });
    }

    // Reset tick window counters so each tick applies once.
    const resetData = {
      tickId: admin.firestore.FieldValue.increment(1),
      windowStartedAt: tickTs,
      lastUpdatedAt: tickTs,
    };

    // Clear both nested-map and flat-key representations (FieldValue.delete requires the exact field path).
    for (const s of STOCKS) {
      const sym = s.symbol;
      resetData[`resourceTradeUnits.${sym}`] = admin.firestore.FieldValue.delete();
      resetData[`resourceTradeNotional.${sym}`] = admin.firestore.FieldValue.delete();
      resetData[`buyOrderUnits.${sym}`] = admin.firestore.FieldValue.delete();
      resetData[`buyOrderNotional.${sym}`] = admin.firestore.FieldValue.delete();
      resetData[`productionUnits.${sym}`] = admin.firestore.FieldValue.delete();
      resetData[`stockTradeBuyNotional.${sym}`] = admin.firestore.FieldValue.delete();
      resetData[`stockTradeSellNotional.${sym}`] = admin.firestore.FieldValue.delete();
    }

    tickBatch.set(stockSignalsRef(), resetData, {merge: true});

    await tickBatch.commit();

    logger.info("cpuMinions summary", {
      sellCreated: sell.createdCount,
      sellUnitsAdded: sell.unitsAdded,
      sellItemsTouched: sell.itemsTouched,
      buyOrdersCreated: buy.createdOrders,
      buyEscrowSpent: buy.escrowSpent,
    });

    await db.collection("worldState").doc("worldTick").set(
      {
        lastCpuMinionsAt: admin.firestore.Timestamp.now(),
        lastCpuSellCreated: sell.createdCount,
        lastCpuSellUnitsAdded: sell.unitsAdded,
        lastCpuBuyOrdersCreated: buy.createdOrders,
        lastCpuBuyEscrowSpent: buy.escrowSpent,
        lastAggregatesUpdatedAt: admin.firestore.Timestamp.now(),
        lastStocksUpdatedAt: admin.firestore.Timestamp.now(),
        lockUntil: null,
        lockOwner: null,
      },
      {merge: true},
    );
  } catch (err) {
    logger.error("worldTick failed", {error: String(err)});
    await db.collection("worldState").doc("worldTick").set(
      {
        lastErrorAt: admin.firestore.Timestamp.now(),
        lastError: String(err),
        lockUntil: null,
        lockOwner: null,
      },
      {merge: true},
    );
  }

  return null;
});

/**
 * Scheduled cleanup: removes old documents from public channel message subcollections only.
 * Does not touch directChats.
 *
 * Query per room: createdAt < cutoff, ordered by createdAt ascending, batched deletes.
 * If the deploy logs an index error, open the printed URL once to create the composite index.
 */
exports.purgePublicChatMessages = onSchedule(
  {
    schedule: "0 6 * * *", // 06:00 UTC daily
    timeZone: "Etc/UTC",
    timeoutSeconds: 540,
    memory: "512MiB",
  },
  async (event) => {
    const retentionMs = PUBLIC_CHAT_RETENTION_DAYS * 24 * 60 * 60 * 1000;
    const cutoff = admin.firestore.Timestamp.fromMillis(Date.now() - retentionMs);

    logger.info("purgePublicChatMessages start", {
      cutoffISO: cutoff.toDate().toISOString(),
      retentionDays: PUBLIC_CHAT_RETENTION_DAYS,
      rooms: PUBLIC_CHAT_ROOM_IDS,
    });

    let totalDeleted = 0;

    for (const roomId of PUBLIC_CHAT_ROOM_IDS) {
      const colRef = db.collection("publicChats").doc(roomId).collection("messages");
      let roomDeleted = 0;
      let rounds = 0;

      while (rounds < PUBLIC_CHAT_MAX_ROUNDS_PER_ROOM) {
        rounds += 1;
        const snap = await colRef
          .where("createdAt", "<", cutoff)
          .orderBy("createdAt", "asc")
          .limit(PUBLIC_CHAT_DELETE_BATCH)
          .get();

        if (snap.empty) break;

        const batch = db.batch();
        for (const doc of snap.docs) {
          batch.delete(doc.ref);
        }
        await batch.commit();

        roomDeleted += snap.size;
        totalDeleted += snap.size;

        if (snap.size < PUBLIC_CHAT_DELETE_BATCH) break;
      }

      logger.info("purgePublicChatMessages room summary", {
        roomId,
        deleted: roomDeleted,
        rounds,
      });
    }

    await db.collection("worldState").doc("publicChatPurge").set(
      {
        lastRunAt: admin.firestore.Timestamp.now(),
        schedule: "0 6 * * * UTC",
        retentionDays: PUBLIC_CHAT_RETENTION_DAYS,
        cutoffAt: cutoff,
        totalDeleted: totalDeleted,
      },
      {merge: true},
    );

    logger.info("purgePublicChatMessages complete", {totalDeleted});
    return null;
  },
);
