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
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            Group {
                if viewModel.isLoading {
                    ProgressView("Loading market listings...")
                        .controlSize(.large)
                        .tint(.white)
                        .foregroundStyle(AppTheme.textPrimary)
                } else if let loadingErrorMessage = viewModel.loadingErrorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Failed to load market")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(loadingErrorMessage)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(AppTheme.textError)
                    }
                    .padding(AppTheme.horizontalPadding)
                } else if viewModel.mineListings.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("No Mine Listings Yet")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Prospected mine and rig listings will appear here once players post them.")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(AppTheme.cardPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .themedCard()
                    .padding(.horizontal, AppTheme.horizontalPadding)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            if let actionErrorMessage = viewModel.actionErrorMessage {
                                Text(actionErrorMessage)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(AppTheme.textError)
                                    .padding(.horizontal, 4)
                            }

                            ForEach(viewModel.mineListings) { listing in
                                listingCard(listing: listing)
                            }
                        }
                        .padding(.horizontal, AppTheme.horizontalPadding)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Market")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
            }
        }
        .onAppear {
            viewModel.loadListings()
        }
        .sheet(item: $viewModel.selectedListingForBid) { listing in
            bidSheetView(listing: listing)
        }
    }

    private func listingCard(listing: MineMarketListing) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 12) {
                Text(viewModel.mineLabel(for: listing.resourceType))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        row("Level", "\(listing.level)")
                        row("Abundance", "\(listing.abundance)")
                        row("Stability", "\(listing.stability)")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        row("Current Bid", "$\(listing.currentBid, specifier: "%.2f")")
                        row("Buy Now", "$\(listing.buyNowPrice, specifier: "%.2f")")
                            .foregroundStyle(AppTheme.textPrimary)
                            .fontWeight(.semibold)
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                }

                if listing.endsAt > context.date {
                    Text("Time Remaining: \(viewModel.formattedTimeRemaining(until: listing.endsAt, now: context.date))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.textTertiary)
                } else {
                    Text("Auction Ended")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.textTertiary)
                }

                if listing.sellerID == userID {
                    if listing.currentBidderID == nil || listing.currentBidderID?.isEmpty == true {
                        Button("Cancel Listing") {
                            viewModel.cancelListing(listing)
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(AppTheme.cardBackgroundAlt)
                        .clipShape(Capsule())
                        .disabled(viewModel.isSubmitting)
                    } else {
                        Text("Listing has bids and cannot be cancelled.")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                } else {
                    HStack(spacing: 10) {
                        Button("Buy Now") {
                            viewModel.buyNow(listing)
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(AppTheme.chipReady)
                        .clipShape(Capsule())
                        .disabled(viewModel.isSubmitting || listing.endsAt <= context.date)

                        Button("Place Bid") {
                            viewModel.openBidSheet(for: listing)
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(AppTheme.cardBackgroundAlt)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(AppTheme.cardBorder, lineWidth: 1)
                        )
                        .disabled(viewModel.isSubmitting || listing.endsAt <= context.date)
                    }
                }
            }
            .padding(AppTheme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .themedCard()
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label + ":")
                .foregroundStyle(AppTheme.textTertiary)
            Text(value)
        }
    }

    private func bidSheetView(listing: MineMarketListing) -> some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

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
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Bid on Listing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.cardBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        viewModel.closeBidSheet()
                    }
                    .foregroundStyle(AppTheme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Submit Bid") {
                        viewModel.submitBid(listing)
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.chipReady)
                    .disabled(viewModel.isSubmitting)
                }
            }
            .overlay {
                if viewModel.isSubmitting {
                    ProgressView("Submitting...")
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
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
