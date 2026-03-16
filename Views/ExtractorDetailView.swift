//
//  ExtractorDetailView.swift
//  Boardroom Tycoon
//
//  Dedicated detail view for mines, rigs, and quarries.
//

import SwiftUI

struct ExtractorDetailView: View {
    let userID: String
    let building: Building

    var body: some View {
        BuildingDetailView(userID: userID, building: building)
    }
}

#Preview {
    NavigationStack {
        ExtractorDetailView(
            userID: "demo-user-id-12345",
            building: Building(
                id: "building-starter-gold-mine",
                name: "Starter Gold Mine",
                type: .mine,
                level: 1,
                capacity: 1,
                slotIndex: 0,
                resourceType: .gold,
                abundance: 50,
                isStarterMine: true,
                isProducing: false,
                productionStartedAt: nil,
                productionEndsAt: nil,
                pendingOutputQuantity: nil,
                pendingOutputItemId: nil,
                pendingOutputItemName: nil,
                isListedOnMarket: false,
                marketListingID: nil
            )
        )
    }
}

