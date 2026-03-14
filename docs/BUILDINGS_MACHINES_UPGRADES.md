# Buildings, Machines & Upgrades — Design Spec

This document captures the design for building levels, machine slots, and upgrade paths. It aligns with the production/refining/retail mind map and the roadmap (Phase 16).

---

## Overview

- **Buildings** are owned facilities (extractors or non-extractors). They have a **level** (1–5) that determines how many **machines** can be installed.
- **Machines** run inside buildings. Players install more machines (up to building capacity) and upgrade each machine with specific **upgrade resources**.
- **Extractors** (mines, rigs, quarry): machines are like “drills”; each machine has its own **abundance** and **stability** (upgradeable to 100/100). New machines in the same building inherit the building’s prospecting stats.
- **Non-extractors** (refineries, shops, plants, mills): each machine has a **set output value per cycle**; upgrading increases that value up to a later-determined cap.

---

## Building Upgrades (Level 1 → 5)

| Concept | Design |
|--------|--------|
| **Level range** | 1–5 |
| **Capacity** | Building level = max number of machines. Level 1 → 1 machine, Level 5 → 5 machines. |
| **Upgrade cost** | **Building upgrade resources** (construction materials). Consuming these resources levels up the building. |
| **Resources (from mind map)** | **Steel Beams**, **Walls**, **Foundation**, **Window** (outputs of Fabrication Plant, Construction Materials Plant, Material Depot). |

So: upgrade building with Steel Beams, Walls, Foundation, Window → building level increases → player can install more machines (up to level count).

---

## Machines Inside Buildings

### Installing machines

- Players **buy/install** additional machines with **cash**, up to the building’s current capacity (building level).
- **Price scales per machine added**: the 2nd machine costs more than the 1st, the 3rd more than the 2nd, etc. Exact formula TBD (e.g. base × machine index, or tiered brackets).
- Capacity is fixed by building level only (no separate “slot” count). You must upgrade the building (with construction materials) to get more capacity before you can buy more machines.

### Extractor buildings (mines, rigs, quarry)

| Concept | Design |
|--------|--------|
| **Machine type** | Treated as “drills” (or similar) — one per slot. |
| **Starting state** | Building starts with **one machine** installed. Its **abundance** and **stability** come from prospecting (the building’s revealed stats). |
| **Additional machines** | Buying a 2nd (or 3rd, etc.) machine gives it the **same** abundance and stability as the building’s prospecting result. So all machines in that building share the same base stats initially. |
| **Per-machine upgrades** | Upgrading a **machine** (with machine upgrade resources) improves **that machine’s** abundance and stability only. |
| **Cap** | Each machine can be upgraded until **100 abundance** and **100 stability**. |
| **Cost curve** | Upgrade **price scales per upgrade** (e.g. each next level costs more). So a good prospecting roll (high abundance/stability) is valuable — fewer upgrades needed to reach 100/100. |

So: one extractor building = one set of prospecting stats, multiple “drills” that each have their own upgradeable abundance/stability up to 100/100.

### Non-extractor buildings (refinery, shop, plant, mill)

| Concept | Design |
|--------|--------|
| **Machine output** | Each machine has a **set output value per cycle** (e.g. units of output per recipe run). |
| **Upgrading machines** | Upgrade a machine with **machine upgrade resources** → that machine’s **output value per cycle** increases. |
| **Cap** | Capped at a **later-determined value** (TBD). |

So: non-extractor machines are about throughput per cycle, not abundance/stability.

---

## Upgrade Resources (from mind map)

### Machine upgrades (consumed to upgrade a machine)

- **Machine Computer** (Tech Plant)
- **Precision Cutting Heads** (Diamond Processing Plant)
- **Diamond Drill Bits** (Diamond Processing Plant)
- **Machine Gear** (Fabrication Plant)
- **Robotic Machine Arms** (Fabrication Plant)

### Building upgrades (consumed to upgrade a building level)

- **Steel Beams** (Fabrication Plant)
- **Walls** (Material Depot)
- **Foundation** (Material Depot)
- **Window** (Material Depot)

---

## Summary Table

| Item | Extractors | Non-extractors |
|------|------------|----------------|
| Building level | 1–5 | 1–5 |
| Max machines | = building level (1–5) | = building level (1–5) |
| Building upgrade cost | Steel Beams, Walls, Foundation, Window | Same |
| **Add machine cost** | **Cash; price scales per machine added** (2nd > 1st, 3rd > 2nd, …) | Same |
| Machine starting stats | 1 machine with prospecting abundance/stability; extra machines copy those stats | Machines have set output value per cycle |
| Machine upgrade cost | Machine Computer, Precision Cutting Heads, Diamond Drill Bits, Machine Gear, Robotic Machine Arms | Same |
| Machine upgrade effect | Per-machine abundance & stability → cap 100/100; cost scales per upgrade | Per-machine output value per cycle → cap TBD |

---

## Implementation notes (for Phase 16)

- **Building:** `level` (1–5) and `capacity` can be aligned so `capacity == level` (max machines). Building upgrade flow: check player has required building-upgrade items → consume them → increment building level (and capacity).
- **Installing a machine:** Player pays **cash**; cost **scales per machine added** (2nd machine more than 1st, 3rd more than 2nd, etc.). Building must have capacity (level) and an empty slot before purchase.
- **Machines:** Persist per building (e.g. subcollection or array). Each machine has: for extractors, `abundance`, `stability` (and level if desired); for non-extractors, `outputValuePerCycle` (and level if desired). New extractor machines copy building’s prospecting abundance/stability when installed.
- **Recipes/items:** Ensure items exist (or are added) for: Machine Computer, Precision Cutting Heads, Diamond Drill Bits, Machine Gear, Robotic Machine Arms, Steel Beams, Walls, Foundation, Window. Use these in upgrade logic and UI.
- **Extractor production:** Either run one cycle per machine and sum outputs, or define “building output” from all machines (e.g. sum of per-machine output from abundance/stability). Same design choice for non-extractors (sum of per-machine output value).

This doc is the single source of truth for the buildings/machines/upgrades design and matches the mind map and your written spec.
