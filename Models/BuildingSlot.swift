//
//  BuildingSlot.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/12/26.
//

import Foundation

enum BuildingSlotContent {
    case building(Building)
    case prospecting(ProspectingJob)
    case empty
}

struct BuildingSlot: Identifiable {
    let id: String
    let content: BuildingSlotContent
}
