//
//  CPUOrder.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/12/26.
//

import Foundation

struct CPUOrder: Identifiable {
    let id: String
    let buyerType: String
    let itemID: String
    let itemName: String
    let quantityRemaining: Double
    let pricePerUnit: Double
    let isActive: Bool
}


