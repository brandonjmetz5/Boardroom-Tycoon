//
//  Machine.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/11/26.
//
//  Extractors: abundance/stability per machine (upgradeable to 100/100).
//  Non-extractors: outputValuePerCycle (upgradeable to cap).
//

import Foundation

struct Machine: Identifiable {
    let id: String
    let name: String
    /// Upgrade level (0 = base). Used for scaling upgrade cost.
    var level: Int
    /// Legacy; for non-extractors can reflect output multiplier.
    var efficiencyBonus: Double

    // MARK: - Extractor (drill) stats
    /// Abundance 1–100. New machines inherit building's prospecting value.
    var abundance: Int?
    /// Stability 1–100.
    var stability: Int?

    // MARK: - Non-extractor
    /// Output units per cycle. Upgrading increases this (cap TBD).
    var outputValuePerCycle: Double?

    /// Display name for extractor machines (e.g. "Drill").
    static let extractorMachineName = "Drill"
    /// Default output value per cycle for new non-extractor machines.
    static let defaultOutputValuePerCycle: Double = 1.0
    /// Cap for non-extractor output value per cycle.
    static let maxOutputValuePerCycle: Double = 5.0
    /// Cap for extractor abundance and stability.
    static let maxAbundanceStability = 100

    init(id: String, name: String, level: Int, efficiencyBonus: Double, abundance: Int? = nil, stability: Int? = nil, outputValuePerCycle: Double? = nil) {
        self.id = id
        self.name = name
        self.level = level
        self.efficiencyBonus = efficiencyBonus
        self.abundance = abundance
        self.stability = stability
        self.outputValuePerCycle = outputValuePerCycle
    }
}
