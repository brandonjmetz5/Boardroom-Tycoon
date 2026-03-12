//
//  MarketView.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/11/26.
//

import SwiftUI

struct MarketView: View {
    @State private var listings: [MarketListing] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let marketListingService = MarketListingService()

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading market listings...")
                    .controlSize(.large)
            } else if let errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Failed to load market")
                        .font(.headline)

                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
                .padding()
            } else if listings.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("No Listings Yet")
                        .font(.headline)

                    Text("Player market listings will appear here once items are posted for sale.")
                        .foregroundStyle(.secondary)
                }
                .padding()
            } else {
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
        }
        .onAppear {
            loadMarketListings()
        }
    }

    private func loadMarketListings() {
        marketListingService.fetchMarketListings { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let loadedListings):
                    self.listings = loadedListings
                    self.isLoading = false
                    self.errorMessage = nil
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
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
