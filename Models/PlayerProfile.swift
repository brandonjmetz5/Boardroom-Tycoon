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
    var starterMineClaimed: Bool
    var createdAt: Date
}
