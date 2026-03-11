//
//  ItemCategory.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/11/26.
//

import Foundation

enum ItemCategory: String, CaseIterable, Identifiable {
    case rawMaterial = "Raw Material"
    case refinedMaterial = "Refined Material"
    case fuel = "Fuel"
    case component = "Component"
    case luxuryGood = "Luxury Good"
    case buildingMaterial = "Building Material"

    var id: String { rawValue }
}
