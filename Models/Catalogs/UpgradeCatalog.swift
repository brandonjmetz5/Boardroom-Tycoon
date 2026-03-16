//
//  UpgradeCatalog.swift
//  Boardroom Tycoon
//
//  Item IDs for building and machine upgrades (match inventory document IDs).
//  Level-specific building costs; machine-type-specific upgrade resources.
//

import Foundation

enum UpgradeCatalog {
    // MARK: - Building upgrade (construction materials)
    // Level 1→2: Foundation, 2→3: Walls, 3→4: Window, 4→5: Steel Beams

    static let buildingUpgradeItemIDs: [String] = [
        "steel-beams",
        "walls",
        "foundation",
        "window"
    ]

    /// Base required items for upgrading FROM currentLevel TO (currentLevel + 1). One item type per tier (base quantity 1).
    private static func buildingUpgradeBaseRequirement(forLevel currentLevel: Int) -> [(itemID: String, baseQuantity: Double)] {
        switch currentLevel {
        case 1: return [("foundation", 1)]   // 1→2
        case 2: return [("walls", 1)]         // 2→3
        case 3: return [("window", 1)]       // 3→4
        case 4: return [("steel-beams", 1)]  // 4→5
        default: return []
        }
    }

    /// Required items for upgrading FROM currentLevel TO (currentLevel + 1). Quantities scaled by upgrade cost multiplier (ceil for whole items).
    static func buildingUpgradeRequirement(forLevel currentLevel: Int) -> [(itemID: String, quantity: Double)] {
        let targetLevel = currentLevel + 1
        let multiplier = BuildingLevelCatalog.upgradeCostMultiplier(forTargetLevel: targetLevel)
        return buildingUpgradeBaseRequirement(forLevel: currentLevel).map { item in
            let scaled = (item.baseQuantity * multiplier).rounded(.up)
            return (item.itemID, max(1, scaled))
        }
    }

    /// Human-readable name for building upgrade requirement (for UI).
    static func buildingUpgradeRequirementLabel(forLevel currentLevel: Int) -> String {
        let req = buildingUpgradeRequirement(forLevel: currentLevel)
        return req.map { "\(Int($0.quantity)) \(itemDisplayName($0.itemID))" }.joined(separator: ", ")
    }

    // MARK: - Machine upgrade (by building type) — retained for seed/item reference only; no longer used for upgrades
    // Each building type consumes a specific upgrade item (some require 2).

    static func machineUpgradeRequirement(for buildingType: BuildingType) -> [(itemID: String, quantity: Double)] {
        switch buildingType {
        case .mine:    return [("machine-gear", 1)]
        case .rig:     return [("diamond-drill-bits", 1)]   // oil rig → drill bits
        case .quarry: return [("precision-cutting-heads", 1)]
        case .refinery: return [("machine-computer", 2)]    // 2 resources for refinery
        case .shop:   return [("robotic-machine-arms", 1)]
        case .plant:  return [("robotic-machine-arms", 2)] // 2 for plant
        case .mill:   return [("machine-gear", 1)]
        case .researchAndDevelopment: return []
        }
    }

    static func machineUpgradeRequirementLabel(for buildingType: BuildingType) -> String {
        let req = machineUpgradeRequirement(for: buildingType)
        return req.map { "\(Int($0.quantity)) \(itemDisplayName($0.itemID))" }.joined(separator: ", ")
    }

    private static func itemDisplayName(_ itemID: String) -> String {
        switch itemID {
        case "foundation": return "Foundation"
        case "walls": return "Walls"
        case "window": return "Window"
        case "steel-beams": return "Steel Beams"
        case "machine-gear": return "Machine Gear"
        case "diamond-drill-bits": return "Diamond Drill Bits"
        case "precision-cutting-heads": return "Precision Cutting Heads"
        case "machine-computer": return "Machine Computer"
        case "robotic-machine-arms": return "Robotic Machine Arms"
        default: return itemID
        }
    }

    static let machineUpgradeItemIDs: [String] = [
        "machine-computer",
        "precision-cutting-heads",
        "diamond-drill-bits",
        "machine-gear",
        "robotic-machine-arms"
    ]

    static func isBuildingUpgradeItem(id: String) -> Bool {
        buildingUpgradeItemIDs.contains(id)
    }

    static func isMachineUpgradeItem(id: String) -> Bool {
        machineUpgradeItemIDs.contains(id)
    }

    // MARK: - Seed inventory (all item IDs + display info for testing)

    struct SeedItem {
        let id: String
        let name: String
        let category: String
        let isFractional: Bool
    }

    static let allItemsForSeeding: [SeedItem] = [
        SeedItem(id: "foundation", name: "Foundation", category: "Building Material", isFractional: false),
        SeedItem(id: "walls", name: "Walls", category: "Building Material", isFractional: false),
        SeedItem(id: "window", name: "Window", category: "Building Material", isFractional: false),
        SeedItem(id: "steel-beams", name: "Steel Beams", category: "Building Material", isFractional: false),
        SeedItem(id: "machine-computer", name: "Machine Computer", category: "Component", isFractional: false),
        SeedItem(id: "precision-cutting-heads", name: "Precision Cutting Heads", category: "Component", isFractional: false),
        SeedItem(id: "diamond-drill-bits", name: "Diamond Drill Bits", category: "Component", isFractional: false),
        SeedItem(id: "machine-gear", name: "Machine Gear", category: "Component", isFractional: false),
        SeedItem(id: "robotic-machine-arms", name: "Robotic Machine Arms", category: "Component", isFractional: false),
        SeedItem(id: "fuel-cell", name: "Fuel Cell", category: "Fuel", isFractional: false),
        SeedItem(id: "machinery-fuel-pack", name: "Machinery Fuel Pack", category: "Fuel", isFractional: false),
        SeedItem(id: "raw-gold", name: "Raw Gold", category: "Raw Material", isFractional: false),
        SeedItem(id: "raw-silver", name: "Raw Silver", category: "Raw Material", isFractional: false),
        SeedItem(id: "raw-diamonds", name: "Raw Diamonds", category: "Raw Material", isFractional: false),
        SeedItem(id: "crude-oil", name: "Crude Oil", category: "Raw Material", isFractional: false),
        SeedItem(id: "raw-coal", name: "Raw Coal", category: "Raw Material", isFractional: false),
        SeedItem(id: "raw-iron", name: "Raw Iron", category: "Raw Material", isFractional: false),
        SeedItem(id: "raw-stone", name: "Raw Stone", category: "Raw Material", isFractional: false),
        SeedItem(id: "raw-sand", name: "Raw Sand", category: "Raw Material", isFractional: false),
        SeedItem(id: "raw-gravel", name: "Raw Gravel", category: "Raw Material", isFractional: false),
        SeedItem(id: "gold-bar", name: "Gold Bar", category: "Refined Material", isFractional: true),
        SeedItem(id: "cut-diamond", name: "Cut Diamond", category: "Refined Material", isFractional: false),
        SeedItem(id: "steel", name: "Steel", category: "Building Material", isFractional: false),
        SeedItem(id: "industrial-heat-blocks", name: "Industrial Heat Blocks", category: "Refined Material", isFractional: false),
    ]
}
