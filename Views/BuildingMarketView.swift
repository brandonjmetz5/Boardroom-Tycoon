import SwiftUI

struct BuildingMarketView: View {
    let userID: String

    @StateObject private var viewModel: MarketViewModel

    init(userID: String) {
        self.userID = userID
        _viewModel = StateObject(wrappedValue: MarketViewModel(userID: userID))
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            auctionsContent
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Building Market")
                    .font(AppTheme.titleMedium())
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

    // MARK: - Content

    private var auctionsContent: some View {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func listingCard(listing: MineMarketListing) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            listingCardContent(listing: listing, now: context.date)
        }
    }

    @ViewBuilder
    private func listingCardContent(listing: MineMarketListing, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.mineLabel(for: listing.resourceType))
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    row("Level", "\(listing.level)")
                    row("Abundance", "\(listing.abundance)")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    row("Current Bid", NumberFormatting.currency(listing.currentBid, fractionDigits: 2))
                    row("Buy Now", NumberFormatting.currency(listing.buyNowPrice, fractionDigits: 2))
                        .foregroundStyle(AppTheme.textPrimary)
                        .fontWeight(.semibold)
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
            }

            if listing.endsAt > now {
                Text("Time Remaining: \(viewModel.formattedTimeRemaining(until: listing.endsAt, now: now))")
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
                    .disabled(viewModel.isSubmitting || listing.endsAt <= now)

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
                    .disabled(viewModel.isSubmitting || listing.endsAt <= now)
                }
            }
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
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
                VStack(alignment: .leading, spacing: 16) {
                    if let err = viewModel.actionErrorMessage {
                        Text(err)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.textError)
                    }
                    Text(viewModel.mineLabel(for: listing.resourceType))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Current Bid: \(NumberFormatting.currency(listing.currentBid, fractionDigits: 2))")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(AppTheme.textSecondary)
                    TextField("Your bid", text: $viewModel.bidAmountText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(AppTheme.cardPadding)
            }
            .navigationTitle("Place Bid")
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
                    Button("Bid") {
                        viewModel.submitBid(listing)
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.chipReady)
                    .disabled(viewModel.isSubmitting)
                }
            }
        }
    }
}

