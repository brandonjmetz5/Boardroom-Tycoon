//
//  InventoryItem.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/11/26.
//

import Foundation

struct InventoryItem: Identifiable {
    let id: String
    let item: Item
    var quantity: Double
}
