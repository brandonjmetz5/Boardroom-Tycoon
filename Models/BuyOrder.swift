//
//  BuyOrder.swift
//  Boardroom Tycoon
//
//  Contract-style buy order: one or more resource lines, total price. All-or-nothing fulfillment.
//

import Foundation

/// A single line in a buy order: one resource at one quality and quantity.
struct BuyOrderLine: Identifiable {
    let resourceID: String
    let resourceName: String
    let resourceCategory: String
    let resourceQuality: Int
    let quantity: Double
    let isFractional: Bool

    var id: String { "\(resourceID)-q\(resourceQuality)" }

    /// Inventory document ID for this resource+quality (e.g. "raw-gold", "raw-gold-q2").
    var resourceInventoryDocID: String {
        resourceQuality > 1 ? "\(resourceID)-q\(resourceQuality)" : resourceID
    }
}

struct BuyOrder: Identifiable {
    let id: String
    let buyerUserID: String
    let buyerName: String?
    /// One or more resource lines. Legacy docs may be parsed from single resource fields into one line.
    let lines: [BuyOrderLine]
    /// Total contract price (buyer pays this; seller receives totalPrice - fee).
    let totalPrice: Double
    let feePercent: Double
    /// Cached: totalPrice * (1 - feePercent/100).
    let netToSeller: Double
    let status: String
    let createdAt: Date
    var filledAt: Date?
    var filledByUserID: String?

    var isOpen: Bool { status == "open" }

    /// True if any line matches the given filters (nil means "any").
    func anyLine(matchesCategory category: String?, resourceID rid: String?, quality: Int?) -> Bool {
        lines.contains { line in
            if let c = category, !c.isEmpty, line.resourceCategory != c { return false }
            if let r = rid, !r.isEmpty, line.resourceID != r { return false }
            if let q = quality, q > 0, line.resourceQuality != q { return false }
            return true
        }
    }

    // MARK: - Legacy single-line convenience (for display when order has one line)

    var resourceID: String { lines.first?.resourceID ?? "" }
    var resourceName: String { lines.first?.resourceName ?? "" }
    var resourceCategory: String { lines.first?.resourceCategory ?? "" }
    var resourceQuality: Int { lines.first?.resourceQuality ?? 1 }
    var quantity: Double { lines.first?.quantity ?? 0 }
    var resourceInventoryDocID: String { lines.first?.resourceInventoryDocID ?? "" }
    var pricePerUnit: Double {
        let totalQty = lines.reduce(0) { $0 + $1.quantity }
        return totalQty > 0 ? totalPrice / totalQty : 0
    }
}
