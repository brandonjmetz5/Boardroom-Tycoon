//
//  MarketListing.swift
//  Boardroom Tycoon
//
//  Resource listing: seller lists quantity at price per unit. Buyers can buy any amount up to quantity (partial fills).
//

import Foundation

struct MarketListing: Identifiable {
    let id: String
    let sellerUserID: String
    let sellerName: String?
    let item: Item
    /// Quality tier (1 = base). Matches inventory doc suffix for filtering.
    let quality: Int
    /// Available quantity (decreases as buyers purchase).
    let quantity: Double
    let pricePerUnit: Double

    /// Inventory document ID for this resource+quality (e.g. "raw-gold", "raw-gold-q2").
    var resourceInventoryDocID: String {
        quality > 1 ? "\(item.id)-q\(quality)" : item.id
    }
}
