//
//  MarketView.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/11/26.
//

import SwiftUI

struct MarketView: View {
    let userID: String

    @StateObject private var viewModel: MarketViewModel

    init(userID: String) {
        self.userID = userID
        _viewModel = StateObject(wrappedValue: MarketViewModel(userID: userID))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading market listings...")
                    .controlSize(.large)
            } else if let loadingErrorMessage = viewModel.loadingErrorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Failed to load market")
                        .font(.headline)

                    Text(loadingErrorMessage)
                        .foregroundStyle(.red)
                }
                .padding()
            } else if viewModel.mineListings.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("No Mine Listings Yet")
                        .font(.headline)

                    Text("Prospected mine and rig listings will appear here once players post them.")
                        .foregroundStyle(.secondary)
                }
                .padding()
            } else {
                List {
                    if let actionErrorMessage = viewModel.actionErrorMessage {
                        Section {
                            Text(actionErrorMessage)
                                .foregroundStyle(.red)
                        }
                    }

                    Section {
                        ForEach(viewModel.mineListings) { listing in
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(viewModel.mineLabel(for: listing.resourceType))
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
                                        Text("Time Remaining: \(viewModel.formattedTimeRemaining(until: listing.endsAt, now: context.date))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text("Auction Ended")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    if listing.sellerID == userID {
                                        if listing.currentBidderID == nil || listing.currentBidderID?.isEmpty == true {
                                            Button("Cancel Listing") {
                                                viewModel.cancelListing(listing)
                                            }
                                            .buttonStyle(.bordered)
                                            .disabled(viewModel.isSubmitting)
                                        } else {
                                            Text("Listing has bids and cannot be cancelled.")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    } else {
                                        HStack {
                                            Button("Buy Now") {
                                                viewModel.buyNow(listing)
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .disabled(viewModel.isSubmitting || listing.endsAt <= context.date)

                                            Button("Place Bid") {
                                                viewModel.openBidSheet(for: listing)
                                            }
                                            .buttonStyle(.bordered)
                                            .disabled(viewModel.isSubmitting || listing.endsAt <= context.date)
                                        }
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
            viewModel.loadListings()
        }
        .sheet(item: $viewModel.selectedListingForBid) { listing in
            NavigationStack {
                Form {
                    Section("Place Bid") {
                        Text(viewModel.mineLabel(for: listing.resourceType))
                        Text("Current Bid: $\(listing.currentBid, specifier: "%.2f")")
                        Text("Buy Now: $\(listing.buyNowPrice, specifier: "%.2f")")

                        TextField("Enter bid amount", text: $viewModel.bidAmountText)
                            .keyboardType(.decimalPad)
                    }

                    if let actionErrorMessage = viewModel.actionErrorMessage {
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
                            viewModel.closeBidSheet()
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Submit Bid") {
                            viewModel.submitBid(listing)
                        }
                        .disabled(viewModel.isSubmitting)
                    }
                }
                .overlay {
                    if viewModel.isSubmitting {
                        ProgressView("Submitting...")
                            .padding()
                            .background(.regularMaterial)
                            .cornerRadius(12)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        MarketView(userID: "demo-user-id-12345")
    }
}
