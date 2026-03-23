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
        case "fuel-cell": return 50.00
        case "raw-gold": return 20.00
        case "raw-silver": return 2.00
        case "raw-diamonds": return 25.00
        case "raw-oil", "crude-oil": return 1.00
        case "raw-coal": return 0.30
        case "raw-iron": return 0.50
        case "raw-stone", "stone": return 0.20
        case "raw-sand", "sand": return 0.20
        case "raw-gravel", "gravel": return 0.20
        case "gold-bar": return 45.00
        case "cut-diamond": return 80.00
        case "steel": return 28.00
        case "silver-bar": return 18.00
        case "diamond-dust": return 40.00
        case "microchip": return 220.00
        case "heat-sink": return 90.00
        case "brick": return 8.00
        case "concrete-mix": return 10.00
        case "glass": return 12.00
        case "gold-ring": return 280.00
        case "gold-watch": return 400.00
        case "silver-ring": return 140.00
        case "silver-watch": return 220.00
        case "luxury-ring": return 1100.00
        case "luxury-watch": return 1500.00
        case "processed-coal": return 5.00
        case "gasoline": return 12.00
        case "diesel": return 11.00
        case "iron-bars": return 10.00
        case "steel-beams": return 45.00
        case "machine-gear": return 150.00
        case "robotic-machine-arms": return 420.00
        case "machinery-fuel-pack": return 50.00
        case "industrial-heat-blocks": return 26.00
        case "window": return 80.00
        case "foundation": return 120.00
        case "walls": return 160.00
        case "diamond-drill-bits": return 450.00
        case "precision-cutting-heads": return 400.00
        case "machine-computer": return 1600.00
        default: return nil
        }
    }

    /// Total value for quantity (unitPrice * quantity). Returns nil if no unit price.
    static func value(quantity: Double, itemId: String) -> Double? {
        guard let up = unitPrice(forItemId: itemId) else { return nil }
        return quantity * up
    }
}
