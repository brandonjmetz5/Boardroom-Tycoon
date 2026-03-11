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
}
