//
//  StockPosition.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/12/26.
//

import Foundation

struct StockPosition: Identifiable {
    let id: String
    let symbol: String
    var sharesOwned: Double
    var averageCost: Double
}
