//
//  BuildingType.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/12/26.
//

import Foundation

enum BuildingType: String, CaseIterable, Identifiable {
    case mine = "Mine"
    case rig = "Rig"
    case quarry = "Quarry"
    case refinery = "Refinery"
    case shop = "Shop"
    case plant = "Plant"
    case mill = "Mill"

    var id: String { rawValue }
}
