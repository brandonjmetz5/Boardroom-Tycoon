//
//  PlayerProfile.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/11/26.
//

import Foundation

struct PlayerProfile: Identifiable {
    let id: String
    var cash: Double
    var level: Int
    var xp: Int
    var buildingSlotCount: Int
    var starterMineClaimed: Bool
    /// Global pool of research points earned from the R&D building.
    var researchPoints: Int
    var createdAt: Date
}
