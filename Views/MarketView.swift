//
//  MarketView.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/11/26.
//

import SwiftUI

struct MarketView: View {
    let listings: [MarketListing] = [
        MarketListing(
            id: "listing-001",
            item: Item(id: "raw-gold", name: "Raw Gold", category: .rawMaterial, isFractional: false),
            quantity: 25,
            pricePerUnit: 120.0,
            sellerName: "PlayerOne"
        ),
        MarketListing(
            id: "listing-002",
            item: Item(id: "crude-oil", name: "Crude Oil", category: .rawMaterial, isFractional: false),
            quantity: 40,
            pricePerUnit: 85.0,
            sellerName: "OilKing"
        ),
        MarketListing(
            id: "listing-003",
            item: Item(id: "gold-bar", name: "Gold Bar", category: .refinedMaterial, isFractional: true),
            quantity: 1.75,
            pricePerUnit: 950.0,
            sellerName: "RefineryBoss"
        ),
        MarketListing(
            id: "listing-004",
            item: Item(id: "steel", name: "Steel", category: .buildingMaterial, isFractional: false),
            quantity: 8,
            pricePerUnit: 300.0,
            sellerName: "SteelWorks"
        )
    ]

    var body: some View {
        List(listings) { listing in
            VStack(alignment: .leading, spacing: 4) {
                Text(listing.item.name)
                    .font(.headline)

                Text("Seller: \(listing.sellerName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Quantity: \(formattedQuantity(listing.quantity, isFractional: listing.item.isFractional))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Price Per Unit: $\(listing.pricePerUnit, specifier: "%.2f")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .listStyle(.insetGrouped)
    }

    private func formattedQuantity(_ quantity: Double, isFractional: Bool) -> String {
        if isFractional {
            return String(format: "%.2f", quantity)
        } else {
            return String(Int(quantity))
        }
    }
}

#Preview {
    NavigationStack {
        MarketView()
    }
}
