//
//  BuildingRecipeCatalog.swift
//  Boardroom Tycoon
//
//  Maps building id or name to recipe id(s) for input→output production.
//  Some buildings (e.g. Fabrication Plant) have multiple recipes.
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
        case "gold-refinery", "Gold Refinery": return ["refine-gold"]
        case "oil-refinery", "Oil Refinery": return ["refine-oil"]
        case "coal-refinery", "Coal Refinery": return ["refine-coal"]
        case "iron-refinery", "Iron Refinery": return ["refine-iron"]
        case "gold-processing-plant", "Gold Processing Plant": return ["process-gold"]
        case "fuel-processing-plant", "Fuel Processing Plant": return ["process-fuel"]
        case "fabrication-plant", "Fabrication Plant": return ["fabricate-steel-beams", "fabricate-machine-gear", "fabricate-robotic-arms"]
        case "material-depot", "Material Depot": return ["depot-materials"]
        case "jewelry-shop", "Jewelry Shop": return ["craft-jewelry"]
        default: return []
        }
    }
}
