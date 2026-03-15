//
//  ItemValueCatalog.swift
//  Boardroom Tycoon
//
//  Display unit prices for inventory items ($ value).
//

import Foundation

enum ItemValueCatalog {
    /// Unit price in $ for display (e.g. "worth $X"). Nil = no price / not tradable.
    static func unitPrice(forItemId itemId: String) -> Double? {
        switch itemId {
        case "fuel-cell": return 8.00
        case "raw-gold": return 42.00
        case "raw-silver": return 0.65
        case "raw-diamonds": return 120.00
        case "raw-oil": return 0.85
        case "raw-coal": return 0.12
        case "raw-iron": return 0.08
        case "raw-stone": return 0.02
        case "gold-bar": return 1850.00
        case "cut-diamond": return 450.00
        case "steel": return 0.35
        case "silver-bar": return 22.00
        case "diamond-dust": return 85.00
        case "microchip": return 120.00
        case "heat-sink": return 45.00
        case "brick": return 1.20
        case "concrete-mix": return 2.50
        case "glass": return 3.00
        case "gold-ring": return 4200.00
        case "gold-watch": return 5500.00
        case "silver-ring": return 55.00
        case "silver-watch": return 85.00
        case "luxury-ring": return 8000.00
        case "luxury-watch": return 12000.00
        case "processed-coal": return 0.35
        case "gasoline": return 2.80
        case "diesel": return 2.60
        case "iron-bars": return 1.50
        case "steel-beams": return 8.00
        case "machine-gear": return 95.00
        case "robotic-machine-arms": return 450.00
        case "machinery-fuel-pack": return 25.00
        case "industrial-heat-blocks": return 12.00
        default: return nil
        }
    }

    /// Total value for quantity (unitPrice * quantity). Returns nil if no unit price.
    static func value(quantity: Double, itemId: String) -> Double? {
        guard let up = unitPrice(forItemId: itemId) else { return nil }
        return quantity * up
    }
}
