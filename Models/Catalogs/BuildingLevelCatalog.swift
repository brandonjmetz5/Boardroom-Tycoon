//
//  BuildingLevelCatalog.swift
//  Boardroom Tycoon
//
//  Level-based throughput multipliers and upgrade cost multipliers.
//  No linear 1x,2x,3x,4x,5x — use these tables instead.
//

import Foundation

enum BuildingLevelCatalog {
    /// Throughput multiplier by building level (1–5). Scales recipe inputs and outputs per cycle.
    /// Level 1 = 1.00, Level 2 = 1.75, Level 3 = 2.50, Level 4 = 3.25, Level 5 = 4.00
    static func throughputMultiplier(forLevel level: Int) -> Double {
        switch level {
        case 1: return 1.00
        case 2: return 1.75
        case 3: return 2.50
        case 4: return 3.25
        case 5: return 4.00
        default: return 1.00
        }
    }

    /// Extractor-only output multiplier. Smaller than throughput—abundance stays king.
    /// Level 2 abundance 60 must NOT beat level 1 abundance 100.
    static func extractorOutputMultiplier(forLevel level: Int) -> Double {
        switch level {
        case 1: return 1.00
        case 2: return 1.10
        case 3: return 1.20
        case 4: return 1.30
        case 5: return 1.40
        default: return 1.00
        }
    }

    /// Cost multiplier when upgrading TO this level. Applied to both cash and material costs.
    /// Steeper curve keeps late levels strategic and long-horizon.
    /// Upgrade to 2 = 1.5, to 3 = 3.0, to 4 = 5.0, to 5 = 8.0
    static func upgradeCostMultiplier(forTargetLevel targetLevel: Int) -> Double {
        switch targetLevel {
        case 2: return 1.5
        case 3: return 3.0
        case 4: return 5.0
        case 5: return 8.0
        default: return 1.0
        }
    }

    /// Scale a base quantity by the building's throughput multiplier.
    /// Uses standard rounding (round to nearest) for whole-number consistency.
    static func scaleQuantity(_ base: Double, throughputMultiplier: Double) -> Double {
        (base * throughputMultiplier).rounded()
    }

    /// Scale a base quantity; for fractional items (e.g. gold bar) keep one decimal.
    static func scaleQuantityFractional(_ base: Double, throughputMultiplier: Double) -> Double {
        let scaled = base * throughputMultiplier
        return (scaled * 10).rounded() / 10
    }
}
