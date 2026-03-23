//
//  Stock.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/11/26.
//

import Foundation

struct Stock: Identifiable {
    let id: String
    let name: String
    let symbol: String
    var currentPrice: Double
    var priceChange: Double
    /// Global float for this stock (used for ownership caps).
    var totalShares: Double
    /// Max ownership ratio per player, 0...1 (e.g. 0.25 = 25%).
    var maxOwnershipPercent: Double
}
