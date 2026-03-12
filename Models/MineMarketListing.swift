//
//  MineMarketListing.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/12/26.
//

import Foundation

struct MineMarketListing: Identifiable {
    let id: String
    let sellerID: String
    let resourceType: ResourceType
    let level: Int
    let abundance: Int
    let stability: Int
    let buyNowPrice: Double
    let startingBid: Double
    let currentBid: Double
    let createdAt: Date
    let endsAt: Date
    let status: String
}
