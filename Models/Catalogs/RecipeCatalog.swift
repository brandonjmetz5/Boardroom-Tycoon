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
        case "refine-gold":
            return goldRefineryRecipe
        case "refine-oil":
            return oilRefineryRecipe
        case "refine-coal":
            return coalRefineryRecipe
        case "refine-iron":
            return ironRefineryRecipe
        default:
            return nil
        }
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
}
