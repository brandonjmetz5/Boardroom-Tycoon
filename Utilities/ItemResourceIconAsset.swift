//
//  ItemResourceIconAsset.swift
//  Boardroom Tycoon
//
//  Maps tradeable item display names to catalog image asset names (same rules as Inventory / Market).
//

import Foundation

enum ItemResourceIconAsset {
    /// Asset name in Assets.xcassets, or nil to use the monogram fallback.
    static func assetName(forItemDisplayName name: String) -> String? {
        let key = name.lowercased()
        if key.contains("raw gold") { return "icon_raw_gold" }
        if key.contains("raw silver") { return "icon_raw_silver" }
        if key.contains("raw diamonds") || key == "diamond" { return "icon_raw_diamond" }
        if key.contains("raw coal") { return "icon_raw_coal" }
        if key.contains("raw iron") { return "icon_raw_iron" }
        if key.contains("crude oil") || key.contains("raw oil") || key == "oil" { return "icon_raw_oil" }
        if key.contains("sand quarry") || key == "sand" || key.contains("raw sand") { return "icon_sand" }
        if key.contains("stone quarry") || key == "stone" || key.contains("quarry") || key.contains("raw stone") { return "icon_stone" }
        if key.contains("gravel quarry") || key == "gravel" || key.contains("raw gravel") { return "icon_gravel" }
        if key.contains("fuel cell") { return "icon_fuel_cell" }
        if key.contains("machinery fuel pack") { return "icon_machinery_fuel_pack" }
        if key.contains("gasoline") { return "icon_gasoline" }
        if key.contains("diesel") { return "icon_diesel" }
        if key.contains("processed coal") { return "icon_processed_coal" }
        if key.contains("industrial heat block") || key.contains("industrial heat") { return "icon_industrial_heat_block" }
        if key.contains("steel beam") { return "icon_steel_beam" }
        if key == "steel" { return "icon_steel" }
        if key.contains("iron bar") { return "icon_iron_bar" }
        if key == "glass" { return "icon_glass" }
        if key == "brick" || key.contains("bricks") { return "icon_brick" }
        if key.contains("concrete mix") { return "icon_concrete_mix" }
        if key == "foundation" || key.contains("foundations") { return "icon_foundation" }
        if key == "window" || key.contains("windows") { return "icon_window" }
        if key == "walls" { return "icon_brick_wall" }
        if key == "gold bar" || key.contains("gold bars") { return "icon_gold_bar" }
        if key == "silver bar" || key.contains("silver bars") { return "icon_silver_bar" }
        if key.contains("cut diamond") { return "icon_cut_diamond" }
        if key.contains("diamond dust") { return "icon_diamond_dust" }
        if key.contains("diamond drill bit") { return "icon_diamond_drill_bit" }
        if key.contains("precision cutting head") { return "icon_precision_cutting_head" }
        if key.contains("heat sink") || key.contains("heatsink") { return "icon_heat_sink" }
        if key == "microchip" || key.contains("microchips") { return "icon_microchip" }
        if key.contains("machine computer") || key.contains("machine computers") { return "icon_machine_computer" }
        if key.contains("machine gear") || key.contains("machine gears") { return "icon_machine_gear" }
        if key.contains("robotic machine arm") || key.contains("robotic machine arms") { return "icon_robotic_machine_arm" }
        if key.contains("gold ring") || key.contains("gold rings") { return "icon_gold_ring" }
        if key.contains("silver ring") || key.contains("silver rings") { return "icon_silver_ring" }
        if key.contains("gold watch") || key.contains("gold watches") { return "icon_gold_watch" }
        if key.contains("silver watch") || key.contains("silver watches") { return "icon_silver_watch" }
        if key.contains("luxury ring") || key.contains("luxury rings") { return "icon_luxury_ring" }
        if key.contains("luxury watch") || key.contains("luxury watches") { return "icon_luxury_watch" }
        return nil
    }
}
