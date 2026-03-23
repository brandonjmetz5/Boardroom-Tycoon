#!/usr/bin/env python3
"""
Boardroom Tycoon economy simulator.

Reads live Swift catalog files and estimates:
- Per-recipe cycle profit
- Per-building best recipe profit/day
- Building payback days (best recipe only)

Scenarios:
- floor: 0.70x item reference values
- normal: 1.00x item reference values
- hot: 1.30x item reference values
"""

from __future__ import annotations

import math
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Tuple


ROOT = Path("/Users/brandonmetz/Desktop/Boardroom Tycoon")
BUILDING_CATALOG = ROOT / "Models/Catalogs/BuildingCatalog.swift"
BUILDING_RECIPE_CATALOG = ROOT / "Models/Catalogs/BuildingRecipeCatalog.swift"
ITEM_VALUE_CATALOG = ROOT / "Models/Catalogs/ItemValueCatalog.swift"
RECIPE_CATALOG = ROOT / "Models/Catalogs/RecipeCatalog.swift"


@dataclass
class Ingredient:
    item_id: str
    qty: float


@dataclass
class Recipe:
    recipe_id: str
    name: str
    cycle_min: int
    inputs: List[Ingredient]
    outputs: List[Ingredient]


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def parse_item_values(text: str) -> Dict[str, float]:
    values: Dict[str, float] = {}
    # case "raw-oil", "crude-oil": return 0.85
    for m in re.finditer(r'case\s+(.+?):\s*return\s*([0-9]+(?:\.[0-9]+)?)', text):
        case_expr = m.group(1)
        value = float(m.group(2))
        for key in re.findall(r'"([^"]+)"', case_expr):
            values[key] = value
    return values


def parse_building_costs(text: str) -> Dict[str, float]:
    costs: Dict[str, float] = {}
    pattern = re.compile(
        r'PurchasableBuilding\(\s*id:\s*"([^"]+)",\s*name:\s*"([^"]+)",\s*type:\s*\.[a-zA-Z]+,\s*cost:\s*([0-9_]+)',
        re.S,
    )
    for m in pattern.finditer(text):
        name = m.group(2)
        cost = float(m.group(3).replace("_", ""))
        costs[name] = cost
    return costs


def parse_building_recipe_ids(text: str) -> Dict[str, List[str]]:
    mapping: Dict[str, List[str]] = {}
    # case "gold-refinery", "Gold Refinery": return ["refine-gold"]
    pattern = re.compile(r'case\s+(.+?):\s*return\s*\[([^\]]*)\]')
    for m in pattern.finditer(text):
        keys = re.findall(r'"([^"]+)"', m.group(1))
        ids = re.findall(r'"([^"]+)"', m.group(2))
        for key in keys:
            if " " in key:  # building display name keys
                mapping[key] = ids
    return mapping


def parse_global_recipe_multipliers(text: str) -> Tuple[float, float]:
    in_m = re.search(r"globalInputMultiplier:\s*Double\s*=\s*([0-9.]+)", text)
    out_m = re.search(r"globalOutputMultiplier:\s*Double\s*=\s*([0-9.]+)", text)
    if not in_m or not out_m:
        raise RuntimeError("Could not parse global recipe multipliers.")
    return float(in_m.group(1)), float(out_m.group(1))


def extract_recipe_blocks(text: str) -> Dict[str, str]:
    blocks: Dict[str, str] = {}
    header = re.compile(r'private\s+static\s+var\s+([A-Za-z0-9_]+):\s*Recipe\s*\{')
    starts = [(m.group(1), m.start()) for m in header.finditer(text)]
    for idx, (name, start) in enumerate(starts):
        end = starts[idx + 1][1] if idx + 1 < len(starts) else len(text)
        blocks[name] = text[start:end]
    return blocks


def parse_recipe_from_block(block: str, in_mult: float, out_mult: float) -> Recipe:
    rid = re.search(r'id:\s*"([^"]+)"', block)
    rname = re.search(r'name:\s*"([^"]+)"', block)
    cycle = re.search(r"cycleTimeInMinutes:\s*([0-9]+)", block)
    if not rid or not rname or not cycle:
        raise RuntimeError("Malformed recipe block")

    def parse_ingredients(section_name: str, mult: float) -> List[Ingredient]:
        sec_m = re.search(section_name + r':\s*\[(.*?)\]', block, re.S)
        if not sec_m:
            return []
        sec = sec_m.group(1)
        rows = []
        pat = re.compile(r'item:\s*Item\(id:\s*"([^"]+)".*?quantity:\s*([0-9]+(?:\.[0-9]+)?)', re.S)
        for m in pat.finditer(sec):
            item_id = m.group(1)
            base_qty = float(m.group(2))
            qty = base_qty * mult
            # mimic RecipeCatalog.scaleQuantity behavior:
            # fractional ids in-game are mostly bars; heuristic here.
            fractional = item_id in {"gold-bar", "silver-bar"}
            if fractional:
                qty = round(max(0.1, qty), 1)
            else:
                qty = float(max(1, round(max(0.1, qty))))
            rows.append(Ingredient(item_id=item_id, qty=qty))
        return rows

    return Recipe(
        recipe_id=rid.group(1),
        name=rname.group(1),
        cycle_min=60,  # hard-enforced in tuned recipe path
        inputs=parse_ingredients("inputItems", in_mult),
        outputs=parse_ingredients("outputItems", out_mult),
    )


def parse_recipes(text: str, in_mult: float, out_mult: float) -> Dict[str, Recipe]:
    blocks = extract_recipe_blocks(text)
    recipes: Dict[str, Recipe] = {}
    for block in blocks.values():
        if "Recipe(" not in block:
            continue
        try:
            r = parse_recipe_from_block(block, in_mult, out_mult)
            recipes[r.recipe_id] = r
        except Exception:
            continue
    return recipes


def recipe_profit(recipe: Recipe, values: Dict[str, float], scenario_mult: float) -> Tuple[float, float, float]:
    in_cost = sum(values.get(i.item_id, 0.0) * scenario_mult * i.qty for i in recipe.inputs)
    out_rev = sum(values.get(o.item_id, 0.0) * scenario_mult * o.qty for o in recipe.outputs)
    return in_cost, out_rev, out_rev - in_cost


def main() -> None:
    building_costs = parse_building_costs(read_text(BUILDING_CATALOG))
    building_recipes = parse_building_recipe_ids(read_text(BUILDING_RECIPE_CATALOG))
    item_values = parse_item_values(read_text(ITEM_VALUE_CATALOG))
    in_mult, out_mult = parse_global_recipe_multipliers(read_text(RECIPE_CATALOG))
    recipes = parse_recipes(read_text(RECIPE_CATALOG), in_mult, out_mult)

    scenarios = {"floor": 0.70, "normal": 1.00, "hot": 1.30}

    print("== Economy Simulator ==")
    print(f"Global recipe multipliers -> inputs x{in_mult}, outputs x{out_mult}, cycle=60m")
    print()

    for scenario_name, sm in scenarios.items():
        print(f"## Scenario: {scenario_name} (price x{sm})")
        rows = []
        for building_name, cost in sorted(building_costs.items(), key=lambda kv: kv[1]):
            recipe_ids = building_recipes.get(building_name, [])
            if not recipe_ids:
                continue
            best_profit_day = -10**18
            best_recipe = None
            for rid in recipe_ids:
                r = recipes.get(rid)
                if not r:
                    continue
                _, _, p_cycle = recipe_profit(r, item_values, sm)
                p_day = p_cycle * (24 * 60 / r.cycle_min)
                if p_day > best_profit_day:
                    best_profit_day = p_day
                    best_recipe = rid
            if best_recipe is None:
                continue
            payback = math.inf if best_profit_day <= 0 else cost / best_profit_day
            rows.append((payback, building_name, cost, best_profit_day, best_recipe))

        for payback, name, cost, pday, rid in sorted(rows, key=lambda x: x[0]):
            pb = "inf" if not math.isfinite(payback) else f"{payback:.1f}d"
            print(f"{name:34} cost={cost:9.0f}  best/day={pday:12.2f}  payback={pb:>6}  recipe={rid}")
        print()


if __name__ == "__main__":
    main()

