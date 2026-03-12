//
//  TransactionRecord.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/12/26.
//

import Foundation

struct TransactionRecord: Identifiable {
    let id: String
    let type: String
    let amount: Double
    let description: String
    let createdAt: Date
}
