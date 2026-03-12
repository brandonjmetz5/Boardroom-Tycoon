//
//  MarketView.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/11/26.
//

import SwiftUI

struct MarketView: View {
    let userID: String

    @State private var mineListings: [MineMarketListing] = []
    @State private var isLoading = true
    @State private var loadingErrorMessage: String?
    @State private var actionErrorMessage: String?

    @State private var selectedListingForBid: MineMarketListing?
    @State private var bidAmountText = ""
    @State private var isSubmitting = false

    private let mineMarketService = MineMarketService()

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading market listings...")
                    .controlSize(.large)
            } else if let loadingErrorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Failed to load market")
                        .font(.headline)

                    Text(loadingErrorMessage)
                        .foregroundStyle(.red)
                }
                .padding()
            } else if mineListings.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("No Mine Listings Yet")
                        .font(.headline)

                    Text("Prospected mine and rig listings will appear here once players post them.")
                        .foregroundStyle(.secondary)
                }
                .padding()
            } else {
                List {
                    if let actionErrorMessage {
                        Section {
                            Text(actionErrorMessage)
                                .foregroundStyle(.red)
                        }
                    }

                    Section {
                        ForEach(mineListings) { listing in
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(mineLabel(for: listing.resourceType))
                                        .font(.headline)

                                    Text("Level: \(listing.level)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                    Text("Abundance: \(listing.abundance)")
                                        .font(.subheadline)

                                    Text("Stability: \(listing.stability)")
                                        .font(.subheadline)

                                    Text("Current Bid: $\(listing.currentBid, specifier: "%.2f")")
                                        .font(.subheadline)

                                    Text("Buy Now: $\(listing.buyNowPrice, specifier: "%.2f")")
                                        .font(.subheadline)
                                        .bold()

                                    if listing.endsAt > context.date {
                                        Text("Time Remaining: \(formattedTimeRemaining(until: listing.endsAt, now: context.date))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text("Auction Ended")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    HStack {
                                        Button("Buy Now") {
                                            buyNow(listing)
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .disabled(isSubmitting || listing.sellerID == userID || listing.endsAt <= context.date)

                                        Button("Place Bid") {
                                            actionErrorMessage = nil
                                            bidAmountText = ""
                                            selectedListingForBid = listing
                                        }
                                        .buttonStyle(.bordered)
                                        .disabled(isSubmitting || listing.sellerID == userID || listing.endsAt <= context.date)
                                    }
                                }
                                .padding(.vertical, 6)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Market")
        .onAppear {
            loadListings()
        }
        .sheet(item: $selectedListingForBid) { listing in
            NavigationStack {
                Form {
                    Section("Place Bid") {
                        Text(mineLabel(for: listing.resourceType))
                        Text("Current Bid: $\(listing.currentBid, specifier: "%.2f")")
                        Text("Buy Now: $\(listing.buyNowPrice, specifier: "%.2f")")

                        TextField("Enter bid amount", text: $bidAmountText)
                            .keyboardType(.decimalPad)
                    }

                    if let actionErrorMessage {
                        Section {
                            Text(actionErrorMessage)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .navigationTitle("Bid on Listing")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") {
                            selectedListingForBid = nil
                            bidAmountText = ""
                            actionErrorMessage = nil
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Submit Bid") {
                            submitBid(listing)
                        }
                        .disabled(isSubmitting)
                    }
                }
                .overlay {
                    if isSubmitting {
                        ProgressView("Submitting...")
                            .padding()
                            .background(.regularMaterial)
                            .cornerRadius(12)
                    }
                }
            }
        }
    }

    private func loadListings() {
        isLoading = true
        loadingErrorMessage = nil

        mineMarketService.fetchActiveMineListings { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let listings):
                    self.mineListings = listings
                    self.isLoading = false
                case .failure(let error):
                    self.loadingErrorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func buyNow(_ listing: MineMarketListing) {
        isSubmitting = true
        actionErrorMessage = nil

        mineMarketService.buyNowMineListing(for: userID, listing: listing) { result in
            DispatchQueue.main.async {
                self.isSubmitting = false

                switch result {
                case .success:
                    self.loadListings()
                case .failure(let error):
                    self.actionErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private func submitBid(_ listing: MineMarketListing) {
        guard let bidAmount = Double(bidAmountText), bidAmount > 0 else {
            actionErrorMessage = "Enter a valid bid amount."
            return
        }

        isSubmitting = true
        actionErrorMessage = nil

        mineMarketService.placeBid(for: userID, listing: listing, bidAmount: bidAmount) { result in
            DispatchQueue.main.async {
                self.isSubmitting = false

                switch result {
                case .success:
                    self.selectedListingForBid = nil
                    self.bidAmountText = ""
                    self.loadListings()
                case .failure(let error):
                    self.actionErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private func formattedTimeRemaining(until endDate: Date, now: Date) -> String {
        let remainingSeconds = max(0, Int(ceil(endDate.timeIntervalSince(now))))
        let hours = remainingSeconds / 3600
        let minutes = (remainingSeconds % 3600) / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private func mineLabel(for resourceType: ResourceType) -> String {
        switch resourceType {
        case .gold:
            return "Gold Mine"
        case .silver:
            return "Silver Mine"
        case .diamond:
            return "Diamond Mine"
        case .oil:
            return "Oil Rig"
        case .coal:
            return "Coal Mine"
        case .iron:
            return "Iron Mine"
        default:
            return resourceType.rawValue
        }
    }
}

#Preview {
    NavigationStack {
        MarketView(userID: "demo-user-id-12345")
    }
}
