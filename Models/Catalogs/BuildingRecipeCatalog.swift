//
//  BuildingRecipeCatalog.swift
//  Boardroom Tycoon
//
//  Maps building id or name to recipe id for input→output production.
//

import Foundation

enum BuildingRecipeCatalog {
    /// Recipe id in Firestore `recipes` collection. Prefer building name (purchased buildings have UUID id).
    static func recipeId(forBuildingId buildingId: String) -> String? {
        recipeIdByKey(buildingId)
    }

    /// Lookup by building name (e.g. "Gold Refinery") for purchased buildings.
    static func recipeId(forBuildingName buildingName: String) -> String? {
        recipeIdByKey(buildingName)
    }

    private static func recipeIdByKey(_ key: String) -> String? {
        switch key {
        case "gold-refinery", "Gold Refinery": return "refine-gold"
        case "oil-refinery", "Oil Refinery": return "refine-oil"
        case "coal-refinery", "Coal Refinery": return "refine-coal"
        case "iron-refinery", "Iron Refinery": return "refine-iron"
        case "gold-processing-plant", "Gold Processing Plant": return "process-gold"
        case "fuel-processing-plant", "Fuel Processing Plant": return "process-fuel"
        case "fabrication-plant", "Fabrication Plant": return "fabricate"
        case "material-depot", "Material Depot": return "depot-materials"
        case "jewelry-shop", "Jewelry Shop": return "craft-jewelry"
        default: return nil
        }
    }
}
