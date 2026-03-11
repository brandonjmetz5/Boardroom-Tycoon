//
//  Operation.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/11/26.
//

import Foundation

struct Operation: Identifiable {
    let id: String
    let name: String
    let type: OperationType
    var level: Int
    var capacity: Int
}

