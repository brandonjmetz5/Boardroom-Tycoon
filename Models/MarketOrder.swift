//
//  MarketOrder.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/12/26.
//

import Foundation

struct MarketOrder: Identifiable {
    let id: String
    let buyerID: String
    let buyerName: String
    let itemID: String
    let itemName: String
    let category: ItemCategory
    let isFractional: Bool
    let quantityWanted: Double
    let pricePerUnit: Double
    let isActive: Bool
}
