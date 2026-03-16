//
//  RecipeCatalog.swift
//  Boardroom Tycoon
//
//  Local recipes for refineries/plants when Firestore has no recipe doc.
//  All building recipes defined per game design.
//

import Foundation

enum RecipeCatalog {
    /// Returns a built-in recipe for known ids so production can run without Firestore recipes.
    static func recipe(forId recipeId: String) -> Recipe? {
        switch recipeId {
        // Refineries
        case "refine-gold": return goldRefineryRecipe
        case "refine-oil-gasoline": return oilRefineryGasolineRecipe
        case "refine-oil-diesel": return oilRefineryDieselRecipe
        case "refine-coal-processed": return coalRefineryProcessedRecipe
        case "refine-coal-heat-blocks": return coalRefineryHeatBlocksRecipe
        case "refine-iron": return ironRefineryRecipe
        case "refine-silver": return silverRefineryRecipe
        case "refine-diamond-cut": return diamondRefineryCutRecipe
        case "refine-diamond-dust": return diamondRefineryDustRecipe
        // Steel Mill
        case "refine-steel": return steelMillRecipe
        // Construction Materials Plant
        case "construct-glass": return constructGlassRecipe
        case "construct-bricks": return constructBricksRecipe
        case "construct-concrete": return constructConcreteRecipe
        // Diamond Processing Plant
        case "process-diamond-drill-bits": return processDiamondDrillBitsRecipe
        case "process-precision-cutting-heads": return processPrecisionCuttingHeadsRecipe
        // Silver Processing Plant
        case "process-silver-ring": return processSilverRingRecipe
        case "process-silver-watch": return processSilverWatchRecipe
        case "process-heatsinks": return processHeatsinksRecipe
        // Gold Processing Plant
        case "process-gold-ring": return processGoldRingRecipe
        case "process-gold-watch": return processGoldWatchRecipe
        case "process-microchip": return processMicrochipRecipe
        // Fuel Processing Plant
        case "process-fuel-cells": return processFuelCellsRecipe
        case "process-machinery-fuel-packs": return processMachineryFuelPacksRecipe
        // Tech Plant
        case "tech-machine-computer": return techMachineComputerRecipe
        // Jewelry Shop
        case "craft-prem-ring": return craftPremRingRecipe
        case "craft-prem-watch": return craftPremWatchRecipe
        case "craft-luxury-ring": return craftLuxuryRingRecipe
        case "craft-luxury-watch": return craftLuxuryWatchRecipe
        // Fabrication Plant
        case "fabricate-steel-beams": return fabricateSteelBeamsRecipe
        case "fabricate-machine-gear": return fabricateMachineGearRecipe
        case "fabricate-robotic-arm": return fabricateRoboticArmRecipe
        // Material Depot
        case "depot-window": return depotWindowRecipe
        case "depot-foundation": return depotFoundationRecipe
        case "depot-walls": return depotWallsRecipe
        default: return nil
        }
    }

    /// All recipes for a building (for multi-recipe buildings). Resolves ids from BuildingRecipeCatalog then local catalog.
    static func recipes(forBuildingName buildingName: String) -> [Recipe] {
        let ids = BuildingRecipeCatalog.recipeIds(forBuildingName: buildingName)
        return ids.compactMap { recipe(forId: $0) }
    }

    static func recipes(forBuildingId buildingId: String) -> [Recipe] {
        let ids = BuildingRecipeCatalog.recipeIds(forBuildingId: buildingId)
        return ids.compactMap { recipe(forId: $0) }
    }

    // MARK: - Refineries

    private static var goldRefineryRecipe: Recipe {
        Recipe(
            id: "refine-gold",
            name: "Gold Bars",
            inputItems: [
                RecipeIngredient(id: "in-raw-gold", item: Item(id: "raw-gold", name: "Raw Gold", category: .rawMaterial, isFractional: false), quantity: 80),
                RecipeIngredient(id: "in-machinery-fuel", item: Item(id: "machinery-fuel-pack", name: "Machinery Fuel Packs", category: .fuel, isFractional: false), quantity: 10)
            ],
            outputItems: [
                RecipeIngredient(id: "out-gold-bar", item: Item(id: "gold-bar", name: "Gold Bars", category: .refinedMaterial, isFractional: true), quantity: 80)
            ],
            cycleTimeInMinutes: 60
        )
    }

    private static var oilRefineryGasolineRecipe: Recipe {
        Recipe(
            id: "refine-oil-gasoline",
            name: "Gasoline",
            inputItems: [
                RecipeIngredient(id: "in-crude-oil", item: Item(id: "crude-oil", name: "Crude Oil", category: .rawMaterial, isFractional: false), quantity: 60),
                RecipeIngredient(id: "in-machinery-fuel", item: Item(id: "machinery-fuel-pack", name: "Machinery Fuel Packs", category: .fuel, isFractional: false), quantity: 10)
            ],
            outputItems: [
                RecipeIngredient(id: "out-gasoline", item: Item(id: "gasoline", name: "Gasoline", category: .refinedMaterial, isFractional: false), quantity: 60)
            ],
            cycleTimeInMinutes: 60
        )
    }

    private static var oilRefineryDieselRecipe: Recipe {
        Recipe(
            id: "refine-oil-diesel",
            name: "Diesel",
            inputItems: [
                RecipeIngredient(id: "in-crude-oil", item: Item(id: "crude-oil", name: "Crude Oil", category: .rawMaterial, isFractional: false), quantity: 60),
                RecipeIngredient(id: "in-machinery-fuel", item: Item(id: "machinery-fuel-pack", name: "Machinery Fuel Packs", category: .fuel, isFractional: false), quantity: 10)
            ],
            outputItems: [
                RecipeIngredient(id: "out-diesel", item: Item(id: "diesel", name: "Diesel", category: .refinedMaterial, isFractional: false), quantity: 60)
            ],
            cycleTimeInMinutes: 60
        )
    }

    private static var coalRefineryProcessedRecipe: Recipe {
        Recipe(
            id: "refine-coal-processed",
            name: "Processed Coal",
            inputItems: [
                RecipeIngredient(id: "in-raw-coal", item: Item(id: "raw-coal", name: "Raw Coal", category: .rawMaterial, isFractional: false), quantity: 70),
                RecipeIngredient(id: "in-machinery-fuel", item: Item(id: "machinery-fuel-pack", name: "Machinery Fuel Packs", category: .fuel, isFractional: false), quantity: 10)
            ],
            outputItems: [
                RecipeIngredient(id: "out-processed-coal", item: Item(id: "processed-coal", name: "Processed Coal", category: .refinedMaterial, isFractional: false), quantity: 70)
            ],
            cycleTimeInMinutes: 60
        )
    }

    private static var coalRefineryHeatBlocksRecipe: Recipe {
        Recipe(
            id: "refine-coal-heat-blocks",
            name: "Industrial Heat Blocks",
            inputItems: [
                RecipeIngredient(id: "in-raw-coal", item: Item(id: "raw-coal", name: "Raw Coal", category: .rawMaterial, isFractional: false), quantity: 70),
                RecipeIngredient(id: "in-machinery-fuel", item: Item(id: "machinery-fuel-pack", name: "Machinery Fuel Packs", category: .fuel, isFractional: false), quantity: 10)
            ],
            outputItems: [
                RecipeIngredient(id: "out-heat-blocks", item: Item(id: "industrial-heat-blocks", name: "Industrial Heat Blocks", category: .refinedMaterial, isFractional: false), quantity: 35)
            ],
            cycleTimeInMinutes: 60
        )
    }

    private static var ironRefineryRecipe: Recipe {
        Recipe(
            id: "refine-iron",
            name: "Iron Bars",
            inputItems: [
                RecipeIngredient(id: "in-raw-iron", item: Item(id: "raw-iron", name: "Raw Iron", category: .rawMaterial, isFractional: false), quantity: 120),
                RecipeIngredient(id: "in-machinery-fuel", item: Item(id: "machinery-fuel-pack", name: "Machinery Fuel Packs", category: .fuel, isFractional: false), quantity: 10)
            ],
            outputItems: [
                RecipeIngredient(id: "out-iron-bars", item: Item(id: "iron-bars", name: "Iron Bars", category: .refinedMaterial, isFractional: false), quantity: 120)
            ],
            cycleTimeInMinutes: 60
        )
    }

    private static var silverRefineryRecipe: Recipe {
        Recipe(
            id: "refine-silver",
            name: "Silver Bars",
            inputItems: [
                RecipeIngredient(id: "in-raw-silver", item: Item(id: "raw-silver", name: "Raw Silver", category: .rawMaterial, isFractional: false), quantity: 100),
                RecipeIngredient(id: "in-machinery-fuel", item: Item(id: "machinery-fuel-pack", name: "Machinery Fuel Packs", category: .fuel, isFractional: false), quantity: 10)
            ],
            outputItems: [
                RecipeIngredient(id: "out-silver-bar", item: Item(id: "silver-bar", name: "Silver Bars", category: .refinedMaterial, isFractional: true), quantity: 100)
            ],
            cycleTimeInMinutes: 60
        )
    }

    private static var diamondRefineryCutRecipe: Recipe {
        Recipe(
            id: "refine-diamond-cut",
            name: "Cut Diamonds",
            inputItems: [
                RecipeIngredient(id: "in-raw-diamonds", item: Item(id: "raw-diamonds", name: "Raw Diamonds", category: .rawMaterial, isFractional: false), quantity: 40),
                RecipeIngredient(id: "in-machinery-fuel", item: Item(id: "machinery-fuel-pack", name: "Machinery Fuel Packs", category: .fuel, isFractional: false), quantity: 10)
            ],
            outputItems: [
                RecipeIngredient(id: "out-cut-diamond", item: Item(id: "cut-diamond", name: "Cut Diamonds", category: .refinedMaterial, isFractional: false), quantity: 40)
            ],
            cycleTimeInMinutes: 60
        )
    }

    private static var diamondRefineryDustRecipe: Recipe {
        Recipe(
            id: "refine-diamond-dust",
            name: "Diamond Dust",
            inputItems: [
                RecipeIngredient(id: "in-raw-diamonds", item: Item(id: "raw-diamonds", name: "Raw Diamonds", category: .rawMaterial, isFractional: false), quantity: 40),
                RecipeIngredient(id: "in-machinery-fuel", item: Item(id: "machinery-fuel-pack", name: "Machinery Fuel Packs", category: .fuel, isFractional: false), quantity: 10)
            ],
            outputItems: [
                RecipeIngredient(id: "out-diamond-dust", item: Item(id: "diamond-dust", name: "Diamond Dust", category: .refinedMaterial, isFractional: false), quantity: 80)
            ],
            cycleTimeInMinutes: 60
        )
    }

    // MARK: - Steel Mill

    private static var steelMillRecipe: Recipe {
        Recipe(
            id: "refine-steel",
            name: "Steel",
            inputItems: [
                RecipeIngredient(id: "in-iron-bars", item: Item(id: "iron-bars", name: "Iron Bars", category: .refinedMaterial, isFractional: false), quantity: 60),
                RecipeIngredient(id: "in-processed-coal", item: Item(id: "processed-coal", name: "Processed Coal", category: .refinedMaterial, isFractional: false), quantity: 30)
            ],
            outputItems: [
                RecipeIngredient(id: "out-steel", item: Item(id: "steel", name: "Steel", category: .buildingMaterial, isFractional: false), quantity: 60)
            ],
            cycleTimeInMinutes: 60
        )
    }

    // MARK: - Construction Materials Plant

    private static var constructGlassRecipe: Recipe {
        Recipe(
            id: "construct-glass",
            name: "Glass",
            inputItems: [
                RecipeIngredient(id: "in-sand", item: Item(id: "sand", name: "Sand", category: .rawMaterial, isFractional: false), quantity: 70),
                RecipeIngredient(id: "in-heat", item: Item(id: "industrial-heat-blocks", name: "Industrial Heat Blocks", category: .refinedMaterial, isFractional: false), quantity: 10)
            ],
            outputItems: [
                RecipeIngredient(id: "out-glass", item: Item(id: "glass", name: "Glass", category: .buildingMaterial, isFractional: false), quantity: 70)
            ],
            cycleTimeInMinutes: 60
        )
    }

    private static var constructBricksRecipe: Recipe {
        Recipe(
            id: "construct-bricks",
            name: "Bricks",
            inputItems: [
                RecipeIngredient(id: "in-stone", item: Item(id: "stone", name: "Stone", category: .rawMaterial, isFractional: false), quantity: 60),
                RecipeIngredient(id: "in-gasoline", item: Item(id: "gasoline", name: "Gasoline", category: .refinedMaterial, isFractional: false), quantity: 20)
            ],
            outputItems: [
                RecipeIngredient(id: "out-brick", item: Item(id: "brick", name: "Bricks", category: .buildingMaterial, isFractional: false), quantity: 60)
            ],
            cycleTimeInMinutes: 60
        )
    }

    private static var constructConcreteRecipe: Recipe {
        Recipe(
            id: "construct-concrete",
            name: "Concrete Mix",
            inputItems: [
                RecipeIngredient(id: "in-gravel", item: Item(id: "gravel", name: "Gravel", category: .rawMaterial, isFractional: false), quantity: 60),
                RecipeIngredient(id: "in-diesel", item: Item(id: "diesel", name: "Diesel", category: .refinedMaterial, isFractional: false), quantity: 20)
            ],
            outputItems: [
                RecipeIngredient(id: "out-concrete-mix", item: Item(id: "concrete-mix", name: "Concrete Mix", category: .buildingMaterial, isFractional: false), quantity: 60)
            ],
            cycleTimeInMinutes: 60
        )
    }

    // MARK: - Diamond Processing Plant

    private static var processDiamondDrillBitsRecipe: Recipe {
        Recipe(
            id: "process-diamond-drill-bits",
            name: "Diamond Drill Bits",
            inputItems: [
                RecipeIngredient(id: "in-cut-diamond", item: Item(id: "cut-diamond", name: "Cut Diamonds", category: .refinedMaterial, isFractional: false), quantity: 20),
                RecipeIngredient(id: "in-heat", item: Item(id: "industrial-heat-blocks", name: "Industrial Heat Blocks", category: .refinedMaterial, isFractional: false), quantity: 10)
            ],
            outputItems: [
                RecipeIngredient(id: "out-diamond-drill-bits", item: Item(id: "diamond-drill-bits", name: "Diamond Drill Bits", category: .component, isFractional: false), quantity: 10)
            ],
            cycleTimeInMinutes: 60
        )
    }

    private static var processPrecisionCuttingHeadsRecipe: Recipe {
        Recipe(
            id: "process-precision-cutting-heads",
            name: "Precision Cutting Heads",
            inputItems: [
                RecipeIngredient(id: "in-cut-diamond", item: Item(id: "cut-diamond", name: "Cut Diamonds", category: .refinedMaterial, isFractional: false), quantity: 20),
                RecipeIngredient(id: "in-heat", item: Item(id: "industrial-heat-blocks", name: "Industrial Heat Blocks", category: .refinedMaterial, isFractional: false), quantity: 10)
            ],
            outputItems: [
                RecipeIngredient(id: "out-precision-cutting-heads", item: Item(id: "precision-cutting-heads", name: "Precision Cutting Heads", category: .component, isFractional: false), quantity: 10)
            ],
            cycleTimeInMinutes: 60
        )
    }

    // MARK: - Silver Processing Plant

    private static var processSilverRingRecipe: Recipe {
        Recipe(
            id: "process-silver-ring",
            name: "Silver Ring",
            inputItems: [
                RecipeIngredient(id: "in-silver-bar", item: Item(id: "silver-bar", name: "Silver Bars", category: .refinedMaterial, isFractional: true), quantity: 20),
                RecipeIngredient(id: "in-processed-coal", item: Item(id: "processed-coal", name: "Processed Coal", category: .refinedMaterial, isFractional: false), quantity: 10)
            ],
            outputItems: [
                RecipeIngredient(id: "out-silver-ring", item: Item(id: "silver-ring", name: "Silver Ring", category: .luxuryGood, isFractional: false), quantity: 10)
            ],
            cycleTimeInMinutes: 45
        )
    }

    private static var processSilverWatchRecipe: Recipe {
        Recipe(
            id: "process-silver-watch",
            name: "Silver Watch",
            inputItems: [
                RecipeIngredient(id: "in-silver-bar", item: Item(id: "silver-bar", name: "Silver Bars", category: .refinedMaterial, isFractional: true), quantity: 20),
                RecipeIngredient(id: "in-processed-coal", item: Item(id: "processed-coal", name: "Processed Coal", category: .refinedMaterial, isFractional: false), quantity: 10)
            ],
            outputItems: [
                RecipeIngredient(id: "out-silver-watch", item: Item(id: "silver-watch", name: "Silver Watch", category: .luxuryGood, isFractional: false), quantity: 5)
            ],
            cycleTimeInMinutes: 45
        )
    }

    private static var processHeatsinksRecipe: Recipe {
        Recipe(
            id: "process-heatsinks",
            name: "Heatsinks",
            inputItems: [
                RecipeIngredient(id: "in-silver-bar", item: Item(id: "silver-bar", name: "Silver Bars", category: .refinedMaterial, isFractional: true), quantity: 30),
                RecipeIngredient(id: "in-heat", item: Item(id: "industrial-heat-blocks", name: "Industrial Heat Blocks", category: .refinedMaterial, isFractional: false), quantity: 10)
            ],
            outputItems: [
                RecipeIngredient(id: "out-heat-sink", item: Item(id: "heat-sink", name: "Heatsinks", category: .component, isFractional: false), quantity: 15)
            ],
            cycleTimeInMinutes: 60
        )
    }

    // MARK: - Gold Processing Plant

    private static var processGoldRingRecipe: Recipe {
        Recipe(
            id: "process-gold-ring",
            name: "Gold Ring",
            inputItems: [
                RecipeIngredient(id: "in-gold-bar", item: Item(id: "gold-bar", name: "Gold Bars", category: .refinedMaterial, isFractional: true), quantity: 20),
                RecipeIngredient(id: "in-processed-coal", item: Item(id: "processed-coal", name: "Processed Coal", category: .refinedMaterial, isFractional: false), quantity: 10)
            ],
            outputItems: [
                RecipeIngredient(id: "out-gold-ring", item: Item(id: "gold-ring", name: "Gold Ring", category: .luxuryGood, isFractional: false), quantity: 10)
            ],
            cycleTimeInMinutes: 45
        )
    }

    private static var processGoldWatchRecipe: Recipe {
        Recipe(
            id: "process-gold-watch",
            name: "Gold Watch",
            inputItems: [
                RecipeIngredient(id: "in-gold-bar", item: Item(id: "gold-bar", name: "Gold Bars", category: .refinedMaterial, isFractional: true), quantity: 20),
                RecipeIngredient(id: "in-processed-coal", item: Item(id: "processed-coal", name: "Processed Coal", category: .refinedMaterial, isFractional: false), quantity: 10)
            ],
            outputItems: [
                RecipeIngredient(id: "out-gold-watch", item: Item(id: "gold-watch", name: "Gold Watch", category: .luxuryGood, isFractional: false), quantity: 5)
            ],
            cycleTimeInMinutes: 45
        )
    }

    private static var processMicrochipRecipe: Recipe {
        Recipe(
            id: "process-microchip",
            name: "Microchip",
            inputItems: [
                RecipeIngredient(id: "in-gold-bar", item: Item(id: "gold-bar", name: "Gold Bars", category: .refinedMaterial, isFractional: true), quantity: 20),
                RecipeIngredient(id: "in-heat", item: Item(id: "industrial-heat-blocks", name: "Industrial Heat Blocks", category: .refinedMaterial, isFractional: false), quantity: 10)
            ],
            outputItems: [
                RecipeIngredient(id: "out-microchip", item: Item(id: "microchip", name: "Microchip", category: .component, isFractional: false), quantity: 15)
            ],
            cycleTimeInMinutes: 60
        )
    }

    // MARK: - Fuel Processing Plant

    private static var processFuelCellsRecipe: Recipe {
        Recipe(
            id: "process-fuel-cells",
            name: "Fuel Cells",
            inputItems: [
                RecipeIngredient(id: "in-gasoline", item: Item(id: "gasoline", name: "Gasoline", category: .refinedMaterial, isFractional: false), quantity: 30),
                RecipeIngredient(id: "in-heat", item: Item(id: "industrial-heat-blocks", name: "Industrial Heat Blocks", category: .refinedMaterial, isFractional: false), quantity: 10)
            ],
            outputItems: [
                RecipeIngredient(id: "out-fuel-cell", item: Item(id: "fuel-cell", name: "Fuel Cells", category: .fuel, isFractional: false), quantity: 30)
            ],
            cycleTimeInMinutes: 45
        )
    }

    private static var processMachineryFuelPacksRecipe: Recipe {
        Recipe(
            id: "process-machinery-fuel-packs",
            name: "Machinery Fuel Packs",
            inputItems: [
                RecipeIngredient(id: "in-diesel", item: Item(id: "diesel", name: "Diesel", category: .refinedMaterial, isFractional: false), quantity: 30),
                RecipeIngredient(id: "in-processed-coal", item: Item(id: "processed-coal", name: "Processed Coal", category: .refinedMaterial, isFractional: false), quantity: 10)
            ],
            outputItems: [
                RecipeIngredient(id: "out-machinery-fuel-pack", item: Item(id: "machinery-fuel-pack", name: "Machinery Fuel Packs", category: .fuel, isFractional: false), quantity: 20)
            ],
            cycleTimeInMinutes: 45
        )
    }

    // MARK: - Tech Plant

    private static var techMachineComputerRecipe: Recipe {
        Recipe(
            id: "tech-machine-computer",
            name: "Machine Computer",
            inputItems: [
                RecipeIngredient(id: "in-microchip", item: Item(id: "microchip", name: "Microchip", category: .component, isFractional: false), quantity: 10),
                RecipeIngredient(id: "in-heat-sink", item: Item(id: "heat-sink", name: "Heatsinks", category: .component, isFractional: false), quantity: 10),
                RecipeIngredient(id: "in-cut-diamond", item: Item(id: "cut-diamond", name: "Cut Diamonds", category: .refinedMaterial, isFractional: false), quantity: 5)
            ],
            outputItems: [
                RecipeIngredient(id: "out-machine-computer", item: Item(id: "machine-computer", name: "Machine Computer", category: .component, isFractional: false), quantity: 5)
            ],
            cycleTimeInMinutes: 60
        )
    }

    // MARK: - Jewelry Shop

    private static var craftPremRingRecipe: Recipe {
        Recipe(
            id: "craft-prem-ring",
            name: "Prem Ring",
            inputItems: [
                RecipeIngredient(id: "in-gold-ring", item: Item(id: "gold-ring", name: "Gold Ring", category: .luxuryGood, isFractional: false), quantity: 5),
                RecipeIngredient(id: "in-silver-ring", item: Item(id: "silver-ring", name: "Silver Ring", category: .luxuryGood, isFractional: false), quantity: 5)
            ],
            outputItems: [
                RecipeIngredient(id: "out-prem-ring", item: Item(id: "prem-ring", name: "Prem Ring", category: .luxuryGood, isFractional: false), quantity: 5)
            ],
            cycleTimeInMinutes: 45
        )
    }

    private static var craftPremWatchRecipe: Recipe {
        Recipe(
            id: "craft-prem-watch",
            name: "Prem Watch",
            inputItems: [
                RecipeIngredient(id: "in-gold-watch", item: Item(id: "gold-watch", name: "Gold Watch", category: .luxuryGood, isFractional: false), quantity: 3),
                RecipeIngredient(id: "in-silver-watch", item: Item(id: "silver-watch", name: "Silver Watch", category: .luxuryGood, isFractional: false), quantity: 3)
            ],
            outputItems: [
                RecipeIngredient(id: "out-prem-watch", item: Item(id: "prem-watch", name: "Prem Watch", category: .luxuryGood, isFractional: false), quantity: 3)
            ],
            cycleTimeInMinutes: 45
        )
    }

    private static var craftLuxuryRingRecipe: Recipe {
        Recipe(
            id: "craft-luxury-ring",
            name: "Luxury Ring",
            inputItems: [
                RecipeIngredient(id: "in-gold-ring", item: Item(id: "gold-ring", name: "Gold Ring", category: .luxuryGood, isFractional: false), quantity: 5),
                RecipeIngredient(id: "in-silver-ring", item: Item(id: "silver-ring", name: "Silver Ring", category: .luxuryGood, isFractional: false), quantity: 5),
                RecipeIngredient(id: "in-cut-diamond", item: Item(id: "cut-diamond", name: "Cut Diamonds", category: .refinedMaterial, isFractional: false), quantity: 5)
            ],
            outputItems: [
                RecipeIngredient(id: "out-luxury-ring", item: Item(id: "luxury-ring", name: "Luxury Ring", category: .luxuryGood, isFractional: false), quantity: 5)
            ],
            cycleTimeInMinutes: 60
        )
    }

    private static var craftLuxuryWatchRecipe: Recipe {
        Recipe(
            id: "craft-luxury-watch",
            name: "Luxury Watch",
            inputItems: [
                RecipeIngredient(id: "in-gold-watch", item: Item(id: "gold-watch", name: "Gold Watch", category: .luxuryGood, isFractional: false), quantity: 3),
                RecipeIngredient(id: "in-silver-watch", item: Item(id: "silver-watch", name: "Silver Watch", category: .luxuryGood, isFractional: false), quantity: 3),
                RecipeIngredient(id: "in-cut-diamond", item: Item(id: "cut-diamond", name: "Cut Diamonds", category: .refinedMaterial, isFractional: false), quantity: 5)
            ],
            outputItems: [
                RecipeIngredient(id: "out-luxury-watch", item: Item(id: "luxury-watch", name: "Luxury Watch", category: .luxuryGood, isFractional: false), quantity: 3)
            ],
            cycleTimeInMinutes: 60
        )
    }

    // MARK: - Fabrication Plant

    private static var fabricateSteelBeamsRecipe: Recipe {
        Recipe(
            id: "fabricate-steel-beams",
            name: "Steel Beams",
            inputItems: [
                RecipeIngredient(id: "in-steel", item: Item(id: "steel", name: "Steel", category: .buildingMaterial, isFractional: false), quantity: 30),
                RecipeIngredient(id: "in-heat", item: Item(id: "industrial-heat-blocks", name: "Industrial Heat Blocks", category: .refinedMaterial, isFractional: false), quantity: 10)
            ],
            outputItems: [
                RecipeIngredient(id: "out-steel-beams", item: Item(id: "steel-beams", name: "Steel Beams", category: .buildingMaterial, isFractional: false), quantity: 20)
            ],
            cycleTimeInMinutes: 60
        )
    }

    private static var fabricateMachineGearRecipe: Recipe {
        Recipe(
            id: "fabricate-machine-gear",
            name: "Machine Gear",
            inputItems: [
                RecipeIngredient(id: "in-steel", item: Item(id: "steel", name: "Steel", category: .buildingMaterial, isFractional: false), quantity: 20),
                RecipeIngredient(id: "in-iron-bars", item: Item(id: "iron-bars", name: "Iron Bars", category: .refinedMaterial, isFractional: false), quantity: 20)
            ],
            outputItems: [
                RecipeIngredient(id: "out-machine-gear", item: Item(id: "machine-gear", name: "Machine Gear", category: .component, isFractional: false), quantity: 20)
            ],
            cycleTimeInMinutes: 60
        )
    }

    private static var fabricateRoboticArmRecipe: Recipe {
        Recipe(
            id: "fabricate-robotic-arm",
            name: "Robotic Machine Arm",
            inputItems: [
                RecipeIngredient(id: "in-iron-bars", item: Item(id: "iron-bars", name: "Iron Bars", category: .refinedMaterial, isFractional: false), quantity: 20),
                RecipeIngredient(id: "in-gold-bar", item: Item(id: "gold-bar", name: "Gold Bars", category: .refinedMaterial, isFractional: true), quantity: 10),
                RecipeIngredient(id: "in-microchip", item: Item(id: "microchip", name: "Microchip", category: .component, isFractional: false), quantity: 5)
            ],
            outputItems: [
                RecipeIngredient(id: "out-robotic-arm", item: Item(id: "robotic-machine-arms", name: "Robotic Machine Arm", category: .component, isFractional: false), quantity: 5)
            ],
            cycleTimeInMinutes: 60
        )
    }

    // MARK: - Material Depot

    private static var depotWindowRecipe: Recipe {
        Recipe(
            id: "depot-window",
            name: "Window",
            inputItems: [
                RecipeIngredient(id: "in-glass", item: Item(id: "glass", name: "Glass", category: .buildingMaterial, isFractional: false), quantity: 20),
                RecipeIngredient(id: "in-heat", item: Item(id: "industrial-heat-blocks", name: "Industrial Heat Blocks", category: .refinedMaterial, isFractional: false), quantity: 10)
            ],
            outputItems: [
                RecipeIngredient(id: "out-window", item: Item(id: "window", name: "Window", category: .buildingMaterial, isFractional: false), quantity: 10)
            ],
            cycleTimeInMinutes: 60
        )
    }

    private static var depotFoundationRecipe: Recipe {
        Recipe(
            id: "depot-foundation",
            name: "Foundation",
            inputItems: [
                RecipeIngredient(id: "in-stone", item: Item(id: "stone", name: "Stone", category: .rawMaterial, isFractional: false), quantity: 20),
                RecipeIngredient(id: "in-concrete-mix", item: Item(id: "concrete-mix", name: "Concrete Mix", category: .buildingMaterial, isFractional: false), quantity: 20),
                RecipeIngredient(id: "in-processed-coal", item: Item(id: "processed-coal", name: "Processed Coal", category: .refinedMaterial, isFractional: false), quantity: 10)
            ],
            outputItems: [
                RecipeIngredient(id: "out-foundation", item: Item(id: "foundation", name: "Foundation", category: .buildingMaterial, isFractional: false), quantity: 10)
            ],
            cycleTimeInMinutes: 60
        )
    }

    private static var depotWallsRecipe: Recipe {
        Recipe(
            id: "depot-walls",
            name: "Walls",
            inputItems: [
                RecipeIngredient(id: "in-brick", item: Item(id: "brick", name: "Bricks", category: .buildingMaterial, isFractional: false), quantity: 20),
                RecipeIngredient(id: "in-iron-bars", item: Item(id: "iron-bars", name: "Iron Bars", category: .refinedMaterial, isFractional: false), quantity: 10)
            ],
            outputItems: [
                RecipeIngredient(id: "out-walls", item: Item(id: "walls", name: "Walls", category: .buildingMaterial, isFractional: false), quantity: 10)
            ],
            cycleTimeInMinutes: 60
        )
    }
}
