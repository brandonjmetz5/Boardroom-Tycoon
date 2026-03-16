//
//  MineMarketListing.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/12/26.
//

import Foundation

import Foundation

struct MineMarketListing: Identifiable {
    let id: String
    let sellerID: String
    let buildingID: String
    let resourceType: ResourceType
    let level: Int
    let abundance: Int
    let buyNowPrice: Double
    let startingBid: Double
    let currentBid: Double
    let currentBidderID: String?
    let createdAt: Date
    let endsAt: Date
    let status: String
}
