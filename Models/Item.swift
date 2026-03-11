//
//  Item.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/11/26.
//

import Foundation

struct Item: Identifiable {
    let id: String
    let name: String
    let category: ItemCategory
    let isFractional: Bool
}
