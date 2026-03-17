const {onRequest} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();

// MARK: - CPU Market Minions config

const CPU_USER_ID = "CPU";
const CPU_DISPLAY_NAME = "Market Board";
const FEE_PERCENT = 3.0;

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
        let lines = [
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
  await db.collection("worldState").doc("worldTick").set(
    {
      lastTickAt: admin.firestore.Timestamp.now(),
      lastTickISO: now,
    },
    {merge: true},
  );

  try {
    await ensureCpuProfile();

    const [listings, openOrders] = await Promise.all([
      fetchAllResourceListings(),
      fetchOpenBuyOrders(),
    ]);

    const sell = await ensureCpuSellSupply(listings);
    const buy = await ensureCpuBuyOrders(openOrders, listings);

    await updateMarketAggregates(listings, openOrders);

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
      },
      {merge: true},
    );
  } catch (err) {
    logger.error("worldTick failed", {error: String(err)});
    await db.collection("worldState").doc("worldTick").set(
      {
        lastErrorAt: admin.firestore.Timestamp.now(),
        lastError: String(err),
      },
      {merge: true},
    );
  }

  return null;
});
