//
//  MarketCatalog.swift
//  Boardroom Tycoon
//
//  Tradeable items for buy orders and market fee constant.
//

import Foundation

enum MarketCatalog {
    /// Flat fee percentage on buy order fulfillment (e.g. 3.0 = 3%).
    static let buyOrderFeePercent: Double = 3.0

    /// Items that can be traded in buy orders (id, name, category, isFractional). Sorted by category then name.
    static func tradeableItems() -> [Item] {
        ItemCategory.allCases.flatMap { category in
            itemsByCategory[category] ?? []
        }.sorted { ($0.category.rawValue, $0.name) < ($1.category.rawValue, $1.name) }
    }

    static func tradeableItems(byCategory category: ItemCategory) -> [Item] {
        (itemsByCategory[category] ?? []).sorted { $0.name < $1.name }
    }

    private static let itemsByCategory: [ItemCategory: [Item]] = [
        .rawMaterial: [
            Item(id: "raw-gold", name: "Raw Gold", category: .rawMaterial, isFractional: false),
            Item(id: "raw-silver", name: "Raw Silver", category: .rawMaterial, isFractional: false),
            Item(id: "raw-diamonds", name: "Raw Diamonds", category: .rawMaterial, isFractional: false),
            Item(id: "raw-oil", name: "Crude Oil", category: .rawMaterial, isFractional: false),
            Item(id: "raw-coal", name: "Raw Coal", category: .rawMaterial, isFractional: false),
            Item(id: "raw-iron", name: "Raw Iron", category: .rawMaterial, isFractional: false),
            Item(id: "raw-stone", name: "Raw Stone", category: .rawMaterial, isFractional: false)
        ],
        .refinedMaterial: [
            Item(id: "gold-bar", name: "Gold Bar", category: .refinedMaterial, isFractional: true),
            Item(id: "cut-diamond", name: "Cut Diamond", category: .refinedMaterial, isFractional: false),
            Item(id: "steel", name: "Steel", category: .refinedMaterial, isFractional: false),
            Item(id: "silver-bar", name: "Silver Bar", category: .refinedMaterial, isFractional: false),
            Item(id: "diamond-dust", name: "Diamond Dust", category: .refinedMaterial, isFractional: false),
            Item(id: "microchip", name: "Microchip", category: .refinedMaterial, isFractional: false),
            Item(id: "heat-sink", name: "Heat Sink", category: .refinedMaterial, isFractional: false),
            Item(id: "processed-coal", name: "Processed Coal", category: .refinedMaterial, isFractional: false),
            Item(id: "gasoline", name: "Gasoline", category: .refinedMaterial, isFractional: false),
            Item(id: "diesel", name: "Diesel", category: .refinedMaterial, isFractional: false),
            Item(id: "iron-bars", name: "Iron Bars", category: .refinedMaterial, isFractional: false),
            Item(id: "industrial-heat-blocks", name: "Industrial Heat Blocks", category: .refinedMaterial, isFractional: false)
        ],
        .fuel: [
            Item(id: "fuel-cell", name: "Fuel Cells", category: .fuel, isFractional: false),
            Item(id: "machinery-fuel-pack", name: "Machinery Fuel Packs", category: .fuel, isFractional: false)
        ],
        .buildingMaterial: [
            Item(id: "brick", name: "Brick", category: .buildingMaterial, isFractional: false),
            Item(id: "concrete-mix", name: "Concrete Mix", category: .buildingMaterial, isFractional: false),
            Item(id: "glass", name: "Glass", category: .buildingMaterial, isFractional: false),
            Item(id: "steel-beams", name: "Steel Beams", category: .buildingMaterial, isFractional: false)
        ],
        .component: [
            Item(id: "machine-gear", name: "Machine Gear", category: .component, isFractional: false),
            Item(id: "robotic-machine-arms", name: "Robotic Machine Arms", category: .component, isFractional: false)
        ],
        .luxuryGood: [
            Item(id: "gold-ring", name: "Gold Ring", category: .luxuryGood, isFractional: false),
            Item(id: "gold-watch", name: "Gold Watch", category: .luxuryGood, isFractional: false),
            Item(id: "silver-ring", name: "Silver Ring", category: .luxuryGood, isFractional: false),
            Item(id: "silver-watch", name: "Silver Watch", category: .luxuryGood, isFractional: false),
            Item(id: "luxury-ring", name: "Luxury Ring", category: .luxuryGood, isFractional: false),
            Item(id: "luxury-watch", name: "Luxury Watch", category: .luxuryGood, isFractional: false)
        ]
    ]
}
