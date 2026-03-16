//
//  BuildingRecipeCatalog.swift
//  Boardroom Tycoon
//
//  Maps building id or name to recipe id(s) for input→output production.
//  Some buildings (e.g. Fabrication Plant, Jewelry Shop) have multiple recipes.
//

import Foundation

enum BuildingRecipeCatalog {
    /// Single recipe id if building has one. Prefer building name (purchased buildings have UUID id).
    static func recipeId(forBuildingId buildingId: String) -> String? {
        recipeIdsByKey(buildingId).first
    }

    static func recipeId(forBuildingName buildingName: String) -> String? {
        recipeIdsByKey(buildingName).first
    }

    /// All recipe ids for this building (e.g. Fabrication Plant has 3). Use for recipe picker.
    static func recipeIds(forBuildingId buildingId: String) -> [String] {
        recipeIdsByKey(buildingId)
    }

    static func recipeIds(forBuildingName buildingName: String) -> [String] {
        recipeIdsByKey(buildingName)
    }

    private static func recipeIdsByKey(_ key: String) -> [String] {
        switch key {
        // Refinery buildings
        case "gold-refinery", "Gold Refinery": return ["refine-gold"]
        case "oil-refinery", "Oil Refinery": return ["refine-oil-gasoline", "refine-oil-diesel"]
        case "coal-refinery", "Coal Refinery": return ["refine-coal-processed", "refine-coal-heat-blocks"]
        case "iron-refinery", "Iron Refinery": return ["refine-iron"]
        case "silver-refinery", "Silver Refinery": return ["refine-silver"]
        case "diamond-refinery", "Diamond Refinery": return ["refine-diamond-cut", "refine-diamond-dust"]
        // Steel Mill
        case "steel-mill", "Steel Mill": return ["refine-steel"]
        // Construction Materials Plant
        case "construction-materials-plant", "Construction Materials Plant": return ["construct-glass", "construct-bricks", "construct-concrete"]
        // Manufacturing
        case "diamond-processing-plant", "Diamond Processing Plant": return ["process-diamond-drill-bits", "process-precision-cutting-heads"]
        case "silver-processing-plant", "Silver Processing Plant": return ["process-silver-ring", "process-silver-watch", "process-heatsinks"]
        case "gold-processing-plant", "Gold Processing Plant": return ["process-gold-ring", "process-gold-watch", "process-microchip"]
        case "fuel-processing-plant", "Fuel Processing Plant": return ["process-fuel-cells", "process-machinery-fuel-packs"]
        case "tech-plant", "Tech Plant": return ["tech-machine-computer"]
        case "jewelry-shop", "Jewelry Shop": return ["craft-luxury-ring", "craft-luxury-watch"]
        case "fabrication-plant", "Fabrication Plant": return ["fabricate-steel-beams", "fabricate-machine-gear", "fabricate-robotic-arm"]
        case "material-depot", "Material Depot": return ["depot-window", "depot-foundation", "depot-walls"]
        default: return []
        }
    }
}
