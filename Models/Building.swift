//
//  Building.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/12/26.
//

import Foundation

struct Building: Identifiable {
    let id: String
    let name: String
    let type: BuildingType
    var level: Int
    var capacity: Int

    var resourceType: ResourceType?
    var abundance: Int?
    var stability: Int?
    var isStarterMine: Bool?

    var isProducing: Bool?
    var productionStartedAt: Date?
    var productionEndsAt: Date?
    var pendingOutputQuantity: Double?
}
