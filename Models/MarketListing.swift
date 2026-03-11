//
//  MarketListing.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/11/26.
//

import Foundation

struct MarketListing: Identifiable {
    let id: String
    let item: Item
    let quantity: Double
    let pricePerUnit: Double
    let sellerName: String
}
