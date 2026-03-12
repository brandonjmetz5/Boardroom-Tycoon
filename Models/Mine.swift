//
//  Mine.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/11/26.
//

import Foundation

struct Mine: Identifiable {
    let id: String
    let operationID: String
    let resourceType: ResourceType
    var level: Int
    var abundance: Int
    var stability: Int
    var isStarterMine: Bool
}
