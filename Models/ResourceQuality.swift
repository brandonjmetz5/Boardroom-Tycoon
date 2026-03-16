//
//  ResourceQuality.swift
//  Boardroom Tycoon
//
//  Tracks per-resource quality level and progress toward next level for a player.
//

import Foundation

struct ResourceQuality: Identifiable {
    let id: String          // base item ID, e.g. "gold-bar"
    var qualityLevel: Int   // 1...N
    var currentResearchPoints: Int
}

