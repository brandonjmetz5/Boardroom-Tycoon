//
//  OperationType.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/11/26.
//

import Foundation

enum OperationType: String, CaseIterable, Identifiable {
    case production = "Production"
    case refinery = "Refinery"
    case retail = "Retail"

    var id: String { rawValue }
}
