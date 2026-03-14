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
        default: return nil
        }
    }

    /// Total value for quantity (unitPrice * quantity). Returns nil if no unit price.
    static func value(quantity: Double, itemId: String) -> Double? {
        guard let up = unitPrice(forItemId: itemId) else { return nil }
        return quantity * up
    }
}
