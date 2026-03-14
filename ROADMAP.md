# Boardroom Tycoon — Project Roadmap

**Last updated:** March 2025 (audit vs. codebase)

---

## North Star

Build a text-first business sim where players:

* own buildings and production assets  
* refine materials  
* craft finished goods  
* trade in player markets  
* speculate on sector stocks  
* prospect for better mines  
* upgrade buildings, mines, and machines  
* grow from weak starter assets into industrial empires  

This roadmap is organized into phases so you always know what matters now and what can wait.

---

## Phase 0 — Foundation and Tooling ✅

**Goal:** Get the project running cleanly and safely before real feature work begins.

**Status:** Done.

**Deliverable:** App launches with Firebase connected. — **Done**

---

## Phase 1 — Authentication and App Shell ✅

**Goal:** The app opens, silently signs in, and lands on a simple home screen.

**Status:** Done.

**Deliverable:** Player opens the app and is silently authenticated with Firebase. — **Done**

---

## Phase 2 — Basic App Architecture ✅

**Goal:** Build the app structure before heavy game logic.

**Status:** Done. MVVM, folders (Models, Views, ViewModels, Services), NavigationStack, tab destinations (Home, Operations, Market, Portfolio, Profile), core models in place.

**Legacy note:** `Operation` / `OperationType` — legacy; remove when safe.

**Deliverable:** App has a clean structure and placeholder screens. — **Done**

---

## Phase 3 — Firebase Data Structure 🔄

**Goal:** Set up the backend shape before building game loops.

**Status:** In progress. Most collections and paths exist; many loops are now real, not just skeleton.

| Collection / path | Status | Notes |
|-------------------|--------|--------|
| playerProfiles | Done | Create/fetch working |
| playerProfiles/{uid}/inventory | Done | Create/fetch working |
| playerProfiles/{uid}/buildings | Done | Fetch, starter mine, production, listing |
| marketListings (mine marketplace) | **Done** | Listings, buy now, bid, cancel, fulfillment |
| marketOrders | Skeleton | Model + service; no full UI loop yet |
| prospectingJobs | **Done** | Start, reveal, keep, list, sell; slot enforcement |
| items | Skeleton | ItemService + fetch; not seeded/UI-integrated |
| recipes | Skeleton | RecipeService + fetch; not wired to buildings/UI |
| cpuOrders | Skeleton | Model + service; no UI/fulfillment |
| stockSymbols / stocks | Skeleton | Fetch + Stocks UI; no trading loop |
| worldState | Skeleton | Model + service; not in gameplay |
| stock positions | Skeleton | Model + service; not in UI/trading |
| notifications | Skeleton | Model + service; not in UI |
| transactions | Skeleton | Model + service; not in UI |

**Player profile:** uid, createdAt, level, xp, cash, buildingSlotCount, starterMineClaimed — Done. displayName, active prospecting ref, stats summary — Not started.

**Deliverable:** Backend structure exists; major loops (profile, inventory, buildings, production, prospecting, mine market) are real. — **In progress**

---

## Phase 4 — Player Start Experience ✅

**Goal:** Give the player a clean first-session flow.

**Status:** Done. Starting cash, 2 slots, one starter mine purchase, first-time behavior via empty states. Dedicated onboarding flow not built.

**Design rules:** Starter mine weak, one per player, no early sector lock; marketplace restriction (starter not listable) not yet enforced.

**Deliverable:** A new player can start and acquire their first production asset. — **Done**

---

## Phase 5 — Building Slot and Progression System 🔄

**Goal:** Building slot framework that controls expansion.

**Status:** In progress.

| Rule | Status |
|------|--------|
| Player starts with 2 building slots | Done |
| Every 10 levels, +2 building slots | **Done** (in `ProductionService.buildingSlotCount(for:)`, applied on collect/level-up) |
| Players choose what to place in slots | Partially done (structure supports; full purchase/build flow partial) |
| Prospecting consumes a slot while active | **Done** (ProspectingService, BuildingService, MineMarketService enforce usedSlots = buildings + active prospecting) |

**Deliverable:** Progression limits expansion through slots. — **In progress** (core rules coded; full UX polish possible)

---

## Phase 6 — Production Asset System 🔄

**Goal:** Mines/rigs/quarry as unique assets.

**Status:** Partially done. Starter mine and building-backed mines work; each has id, resource type, level, abundance, stability; listing state and building relationship exist. “Source” and full listing-state modeling not started.

**Resource types:** Gold in use; Silver, Diamond, Oil, Coal, Iron, Quarry in structure/enum.

**Deliverable:** Production assets exist as unique items with stats. — **Partially done**

---

## Phase 7 — Building System ✅

**Goal:** All player-owned facilities as buildings.

**Status:** Done in structure. Production (mines; rigs/quarry in type enum), refinery, retail (shops, plants, mills); slots, upgrades concept; mines as first-class; refinery/retail with machines (conceptual/mock).

**Deliverable:** Buildings are the main owned business objects. — **Done**

---

## Phase 8 — Building and Detail UI 🔄

**Goal:** Buildings screen reflects real game hierarchy.

**Status:** In progress. Buildings list and building detail exist. Production (mine) detail shows real data, production cycle, collect, list on market, sell to system. Refinery/retail detail still mock (machines).

**Deliverable:** Player can inspect owned buildings in a clean hierarchy. — **In progress**

---

## Phase 9 — Mine Marketplace 🔄

**Goal:** Browse and buy unique production assets.

**Status:** In progress (was “Not started” in prior roadmap).

**Implemented:**  
- Listings show resource type, level, abundance, stability, buy now price, current bid, timer.  
- Browse listings, Buy Now, Place Bid (sheet), Cancel Listing (seller).  
- Market fetches global mine listings; buy/bid/fulfill in MineMarketService.

**Not yet:** Compare-stats UX; enforce “starter mine not listable” in marketplace rules.

**Deliverable:** Mine marketplace works as a major progression path. — **In progress**

---

## Phase 10 — Prospecting System 🔄

**Goal:** Discover new mines instead of only buying.

**Status:** In progress (was “Skeleton only” in prior roadmap).

**Implemented:**  
- Pay to prospect (e.g. $750), choose resource type (Gold, Silver, Diamond, Oil, Coal, Iron, Quarry).  
- One active job enforced; real-time timer; reveal result.  
- After reveal: keep mine (building written) or list on marketplace.  
- Prospecting consumes a building slot (enforced in ProspectingService, BuildingService, MineMarketService).  
- UI: Operations (prospect buttons, slot cards, reveal); Dashboard (active job, time remaining).

**Design identity:** Progression path, gamble, asset generation, mine flipping — all in place conceptually and in code.

**Deliverable:** Players can generate new mines and inject assets into the economy. — **In progress** (core loop done; UX polish possible)

---

## Phase 11 — Production Cycle System 🔄

**Goal:** Buildings run and produce resources.

**Status:** In progress (was “Not started” in prior roadmap).

**Implemented:**  
- Choose building → Building detail.  
- Start cycle (ProductionService.startProduction; 60-min style cycle, productionEndsAt).  
- Wait (UI shows time remaining).  
- Collect output (Collect Output button; ProductionService fulfills to inventory, level/XP, buildingSlotCount update).  
- Slot progression: `buildingSlotCount(for: level)` = 2 + (level/10)*2 on collect.

**Not yet:** Queue multiple cycles; fuel consumed; explicit 60-min rule in one place; underperformance on long runs.

**Deliverable:** Players can produce raw resources on a timer. — **In progress** (first version: start → wait → collect)

---

## Phase 12 — Resource and Item System 🔄

**Goal:** Item backbone of the economy.

**Status:** Partially done. Categories (raw, refined, components, fuel, luxury, construction, upgrade) in design/structure; fractional rule in model. Full item library and Firestore seeding not done; many services still skeleton.

**Deliverable:** Inventory supports all current economy item types. — **Partially done**

---

## Phase 13 — Building Chains and Production Chains 📋

**Goal:** Refinery and retail economy.

**Status:** Design done; no real production/refining/crafting loops coded.

**Deliverable:** All launch production chains exist in system form. — **Design done / code not started**

---

## Phase 14 — Recipe System 🔄

**Goal:** Centralize crafting/refining logic.

**Status:** Skeleton. Recipe model (inputs, outputs, cycle time); building type partial; unlock requirement not started. Base cycles 60 min in design; fractional via item.

**Deliverable:** All buildings can run recipes from a data-driven list. — **Skeleton only**

---

## Phase 15 — Inventory and Storage UX 🔄

**Goal:** Clear view of what the player owns.

**Status:** In progress. Inventory screen, quantity, decimal support. Grouped by category, item detail view, “used in” not done.

**Deliverable:** Inventory readable and usable. — **In progress**

---

## Phase 16 — Machine and Building Upgrade System 📋

**Goal:** Meaningful progression beyond buying more.

**Status:** Design locked (mine abundance/stability, machine upgrades, building capacity/tiers). Implementation not started.

**Design spec:** See `docs/BUILDINGS_MACHINES_UPGRADES.md` for:
- Building level 1–5 → capacity = max machines (1–5)
- Building upgrades: Steel Beams, Walls, Foundation, Window
- Extractor machines (“drills”): per-machine abundance/stability, cap 100/100, scaling upgrade cost; new machines inherit prospecting stats
- Non-extractor machines: output value per cycle, upgradeable to TBD cap
- Machine upgrades: Machine Computer, Precision Cutting Heads, Diamond Drill Bits, Machine Gear, Robotic Machine Arms

**Deliverable:** Multi-path strategic progression. — **Design done / code not started**

---

## Phase 17 — Building Management UI 📋

**Goal:** Players actually run businesses from the UI.

**Status:** Partially done. Current level, mine stats / production status, cycle status, collect output, list/sell to system. Available recipes, fuel, upgrade options not in UI.

**Deliverable:** Buildings feel like real player-owned businesses. — **Partially done** (extractor path; refinery/retail mock)

---

## Phase 18 — Commodity Market 📋

**Goal:** Item trading market (separate from mine marketplace).

**Status:** Skeleton. Market screen fetches listings; mine marketplace is implemented. Item post/buy/fulfill and direct P2P not built.

**Deliverable:** Production economy feels alive via item trading. — **Skeleton only**

---

## Phase 19 — CPU Orders and Demand Sinks 📋

**Goal:** Sinks to avoid oversupply.

**Status:** Skeleton. CPUOrder + CPUOrderService + fetch; no UI or create/fulfill loop.

**Deliverable:** Economy has sinks. — **Skeleton only**

---

## Phase 20 — Diamond Quality and Rarity 📋

**Goal:** Diamonds exciting and high-variance.

**Status:** Design only; not implemented.

**Deliverable:** Diamond chain high-excitement. — **Not started**

---

## Phase 21 — Building Ownership, Transfer, Marketplace Assets 📋

**Goal:** Buy/sell player-owned assets; preserve stats; starter mine never sellable.

**Status:** Partially done (listing/buy/bid/cancel for mines). Transfer semantics and “starter never sellable” enforcement not fully done.

**Deliverable:** Buildings transferable through marketplace. — **In progress** (mine marketplace; starter restriction pending)

---

## Phase 22 — Stock Market Foundation 🔄

**Goal:** Separate financial market concept and data.

**Status:** Skeleton done. Stock, StockPricePoint, StockPosition, StockService, StockPositionService, fetch, Stocks screen with empty state. Real Firestore stock docs and trading loop not built.

**Deliverable:** Stock market system concept in place. — **Skeleton done**

---

## Phase 23 — Stock Trading System 📋

**Goal:** Buy/sell shares.

**Status:** Not started. Current price / movement skeleton-ready in model.

**Deliverable:** Players can speculate on sectors. — **Not started**

---

## Phase 24 — Stock Charting 🔄

**Goal:** Clear stock history display.

**Status:** UI done, data pipeline partial. `StockChartView` and `SparklineView` exist (line chart, gradient). StockPricePoint model exists. Firestore price-history loop not confirmed.

**Deliverable:** Each stock has a visible line chart. — **In progress** (charts built; data may be placeholder)

---

## Phase 25 — Notifications and Timers 📋

**Goal:** Return to meaningful completed actions.

**Status:** Skeleton. AppNotification, NotificationService, fetch; no UI or create/mark-read flow.

**Deliverable:** Players can return to meaningful actions. — **Skeleton only**

---

## Phase 26 — Balance Pass 1 📋

**Goal:** First playable economy loop.

**Status:** Not started.

**Deliverable:** First playable economy loop. — **Not started**

---

## Phase 27 — Polish and QoL 📋

**Goal:** Understandable, pleasant experience.

**Status:** Not started.

**Deliverable:** Game easier to learn. — **Not started**

---

## Phase 28 — Launch MVP 📋

**Goal:** Ship a small but complete version.

**Status:** Roadmap target only.

**Deliverable:** Real launchable v1. — **Not started**

---

## Feature Priority Tiers

### Tier 1 — Must Have

| Feature | Status |
|---------|--------|
| Auth | Done |
| Player profile | Done |
| Starter mine | Done |
| Building slots (+ progression) | Partially done (slot count + prospecting slot use coded) |
| Inventory | Done |
| Basic buildings structure | Done |
| **Production cycle** | **In progress** (start → wait → collect) |
| **Mine marketplace** | **In progress** (browse, buy now, bid, cancel) |
| **Prospecting real loop** | **In progress** (start, reveal, keep, list) |
| Item market real loop | Not started |
| Basic upgrades | Design only |

### Tier 2 — Strong Launch

- Full launch resource chains — Not started  
- CPU orders — Skeleton only  
- Stock market buy/sell — Not started  
- Stock charts — UI done; data pipeline partial  
- Better market UI — Mine market has core UI; polish possible  

### Tier 3 — Later

- All other phases as above  

---

## Biggest Risks To Avoid

1. **Building too much too early** — Still relevant.  
2. **Overcomplicating backend before app shell** — Avoided so far.  
3. **Launching with too many resources** — Keep scope tight.  
4. **Mixing stock market and item market logic** — Keep separate.  
5. **Starter mine exploitable** — Duplicate purchase prevented; marketplace “starter not listable” still to enforce.

---

## Summary of Roadmap Updates (March 2025)

- **Phase 5:** Slot progression (every 10 levels +2 slots) and “prospecting uses a slot” are **coded**.  
- **Phase 9:** Mine marketplace **in progress**: listings, buy now, bid, cancel, timer, stats.  
- **Phase 10:** Prospecting **in progress**: start, reveal, keep, list, slot enforcement, UI.  
- **Phase 11:** Production cycle **in progress**: start → wait → collect; level/slot update on collect.  
- **Phase 24:** Stock chart UI **built** (StockChartView, SparklineView); backend price history may still be skeleton.  
- **Phase 3:** Many backend loops (profile, inventory, buildings, production, prospecting, mine market) are **real**; others (items, recipes, cpuOrders, stocks, worldState, notifications, transactions) still skeleton.

You’re past “skeleton only” for the first full gameplay loop: **prospect or buy mines → produce → collect → level/slots → list/sell**. Next natural focus: enforce starter-mine marketplace rule, then item/recipe data and commodity market or stock trading, depending on priority.
