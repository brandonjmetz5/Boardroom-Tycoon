//
//  ProspectingJob.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/11/26.
//

import Foundation

struct ProspectingJob: Identifiable {
    let id: String
    let resourceType: ResourceType
    let startedAt: Date
    let endsAt: Date
    let slotIndex: Int
    var isComplete: Bool
    var isRevealed: Bool
    var revealedAbundance: Int?
    // Stability has been removed from the design; only abundance is tracked going forward.
}
