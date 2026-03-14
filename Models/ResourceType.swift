//
//  ResourceType.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/11/26.
//

import Foundation

enum ResourceType: String, CaseIterable, Identifiable {
    case gold = "Gold"
    case silver = "Silver"
    case diamond = "Diamond"
    case oil = "Oil"
    case coal = "Coal"
    case iron = "Iron"
    case quarry = "Quarry"           // legacy; treated as Stone Quarry
    case sandQuarry = "Sand Quarry"
    case stoneQuarry = "Stone Quarry"
    case gravelQuarry = "Gravel Quarry"

    var id: String { rawValue }
}
