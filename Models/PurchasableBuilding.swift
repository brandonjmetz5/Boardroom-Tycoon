//
//  PurchasableBuilding.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/12/26.
//

import Foundation

struct PurchasableBuilding: Identifiable {
    let id: String
    let name: String
    let type: BuildingType
    let cost: Double
}
