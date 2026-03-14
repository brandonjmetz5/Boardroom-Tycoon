//
//  RecipeCatalog.swift
//  Boardroom Tycoon
//
//  Local recipes for refineries/plants when Firestore has no recipe doc (e.g. refine-gold).
//

import Foundation

enum RecipeCatalog {
    /// Returns a built-in recipe for known ids so production can run without Firestore recipes.
    static func recipe(forId recipeId: String) -> Recipe? {
        switch recipeId {
        case "refine-gold": return goldRefineryRecipe
        case "refine-oil": return oilRefineryRecipe
        case "refine-coal": return coalRefineryRecipe
        case "refine-iron": return ironRefineryRecipe
        case "fabricate-steel-beams": return fabricateSteelBeamsRecipe
        case "fabricate-machine-gear": return fabricateMachineGearRecipe
        case "fabricate-robotic-arms": return fabricateRoboticArmsRecipe
        default: return nil
        }
    }

    /// All recipes for a building (for multi-recipe buildings like Fabrication Plant). Resolves ids from BuildingRecipeCatalog then local catalog.
    static func recipes(forBuildingName buildingName: String) -> [Recipe] {
        let ids = BuildingRecipeCatalog.recipeIds(forBuildingName: buildingName)
        return ids.compactMap { recipe(forId: $0) }
    }

    static func recipes(forBuildingId buildingId: String) -> [Recipe] {
        let ids = BuildingRecipeCatalog.recipeIds(forBuildingId: buildingId)
        return ids.compactMap { recipe(forId: $0) }
    }

    private static var goldRefineryRecipe: Recipe {
        Recipe(
            id: "refine-gold",
            name: "Refine Gold",
            inputItems: [
                RecipeIngredient(id: "in-machinery-fuel", item: Item(id: "machinery-fuel-pack", name: "Machinery Fuel Pack", category: .fuel, isFractional: false), quantity: 2),
                RecipeIngredient(id: "in-raw-gold", item: Item(id: "raw-gold", name: "Raw Gold", category: .rawMaterial, isFractional: false), quantity: 10)
            ],
            outputItems: [
                RecipeIngredient(id: "out-gold-bar", item: Item(id: "gold-bar", name: "Gold Bar", category: .refinedMaterial, isFractional: true), quantity: 5)
            ],
            cycleTimeInMinutes: 60
        )
    }

    private static var oilRefineryRecipe: Recipe {
        Recipe(
            id: "refine-oil",
            name: "Refine Oil",
            inputItems: [
                RecipeIngredient(id: "in-machinery-fuel", item: Item(id: "machinery-fuel-pack", name: "Machinery Fuel Pack", category: .fuel, isFractional: false), quantity: 2),
                RecipeIngredient(id: "in-crude-oil", item: Item(id: "crude-oil", name: "Crude Oil", category: .rawMaterial, isFractional: false), quantity: 10)
            ],
            outputItems: [
                RecipeIngredient(id: "out-gasoline", item: Item(id: "gasoline", name: "Gasoline", category: .refinedMaterial, isFractional: false), quantity: 5),
                RecipeIngredient(id: "out-diesel", item: Item(id: "diesel", name: "Diesel", category: .refinedMaterial, isFractional: false), quantity: 5)
            ],
            cycleTimeInMinutes: 60
        )
    }

    private static var coalRefineryRecipe: Recipe {
        Recipe(
            id: "refine-coal",
            name: "Refine Coal",
            inputItems: [
                RecipeIngredient(id: "in-machinery-fuel", item: Item(id: "machinery-fuel-pack", name: "Machinery Fuel Pack", category: .fuel, isFractional: false), quantity: 2),
                RecipeIngredient(id: "in-raw-coal", item: Item(id: "raw-coal", name: "Raw Coal", category: .rawMaterial, isFractional: false), quantity: 10)
            ],
            outputItems: [
                RecipeIngredient(id: "out-processed-coal", item: Item(id: "processed-coal", name: "Processed Coal", category: .refinedMaterial, isFractional: false), quantity: 8)
            ],
            cycleTimeInMinutes: 60
        )
    }

    private static var ironRefineryRecipe: Recipe {
        Recipe(
            id: "refine-iron",
            name: "Refine Iron",
            inputItems: [
                RecipeIngredient(id: "in-machinery-fuel", item: Item(id: "machinery-fuel-pack", name: "Machinery Fuel Pack", category: .fuel, isFractional: false), quantity: 2),
                RecipeIngredient(id: "in-raw-iron", item: Item(id: "raw-iron", name: "Raw Iron", category: .rawMaterial, isFractional: false), quantity: 10)
            ],
            outputItems: [
                RecipeIngredient(id: "out-iron-bars", item: Item(id: "iron-bars", name: "Iron Bars", category: .refinedMaterial, isFractional: false), quantity: 6)
            ],
            cycleTimeInMinutes: 60
        )
    }

    // MARK: - Fabrication Plant (3 recipes)
    private static var fabricateSteelBeamsRecipe: Recipe {
        Recipe(
            id: "fabricate-steel-beams",
            name: "Steel Beams",
            inputItems: [
                RecipeIngredient(id: "in-steel", item: Item(id: "steel", name: "Steel", category: .buildingMaterial, isFractional: false), quantity: 4),
                RecipeIngredient(id: "in-heat", item: Item(id: "industrial-heat-blocks", name: "Industrial Heat Blocks", category: .refinedMaterial, isFractional: false), quantity: 2)
            ],
            outputItems: [
                RecipeIngredient(id: "out-steel-beams", item: Item(id: "steel-beams", name: "Steel Beams", category: .buildingMaterial, isFractional: false), quantity: 2)
            ],
            cycleTimeInMinutes: 60
        )
    }

    private static var fabricateMachineGearRecipe: Recipe {
        Recipe(
            id: "fabricate-machine-gear",
            name: "Machine Gear",
            inputItems: [
                RecipeIngredient(id: "in-steel", item: Item(id: "steel", name: "Steel", category: .buildingMaterial, isFractional: false), quantity: 2),
                RecipeIngredient(id: "in-iron", item: Item(id: "iron-bars", name: "Iron Bars", category: .refinedMaterial, isFractional: false), quantity: 3)
            ],
            outputItems: [
                RecipeIngredient(id: "out-machine-gear", item: Item(id: "machine-gear", name: "Machine Gear", category: .component, isFractional: false), quantity: 1)
            ],
            cycleTimeInMinutes: 60
        )
    }

    private static var fabricateRoboticArmsRecipe: Recipe {
        Recipe(
            id: "fabricate-robotic-arms",
            name: "Robotic Machine Arms",
            inputItems: [
                RecipeIngredient(id: "in-iron", item: Item(id: "iron-bars", name: "Iron Bars", category: .refinedMaterial, isFractional: false), quantity: 2),
                RecipeIngredient(id: "in-gold", item: Item(id: "gold-bar", name: "Gold Bar", category: .refinedMaterial, isFractional: true), quantity: 1),
                RecipeIngredient(id: "in-microchip", item: Item(id: "machine-computer", name: "Machine Computer", category: .component, isFractional: false), quantity: 1)
            ],
            outputItems: [
                RecipeIngredient(id: "out-robotic-arms", item: Item(id: "robotic-machine-arms", name: "Robotic Machine Arms", category: .component, isFractional: false), quantity: 1)
            ],
            cycleTimeInMinutes: 60
        )
    }
}
