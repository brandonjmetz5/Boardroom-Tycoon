//
//  UpgradeCatalog.swift
//  Boardroom Tycoon
//
//  Item IDs for building and machine upgrades (match inventory document IDs).
//

import Foundation

enum UpgradeCatalog {
    // MARK: - Building upgrade (construction materials)
    // Consumed to level up building 1→2, 2→3, … 4→5. One of each per level.

    static let buildingUpgradeItemIDs: [String] = [
        "steel-beams",
        "walls",
        "foundation",
        "window"
    ]

    /// Required quantity of each building upgrade item per level (e.g. 1 of each to go from level 1 to 2).
    static let buildingUpgradeQuantityPerLevel: Double = 1

    // MARK: - Machine upgrade (components)
    // Consumed to upgrade a machine (extractor: +abundance/stability; non-extractor: +output value).
    // One of any of these per upgrade.

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
}
