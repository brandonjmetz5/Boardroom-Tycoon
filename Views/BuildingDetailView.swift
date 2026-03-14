//
//  BuildingDetailView.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/12/26.
//

import SwiftUI

struct BuildingDetailView: View {
    let userID: String
    let building: Building

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: BuildingDetailViewModel

    init(userID: String, building: Building) {
        self.userID = userID
        self.building = building
        _viewModel = StateObject(wrappedValue: BuildingDetailViewModel(userID: userID, building: building))
    }

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                    overviewCard
                    if viewModel.isExtractor {
                        mineDetailsSection
                        productionSection
                        managementSection
                        machinesSection
                    } else {
                        productionSectionNonExtractor
                        managementSectionNonExtractor
                        machinesSection
                    }
                    seedFirestoreSection
                }
                .padding(.horizontal, AppTheme.horizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(viewModel.currentBuilding.name)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .onAppear {
            viewModel.onDismiss = { dismiss() }
            viewModel.refreshBuilding()
        }
        .sheet(isPresented: $viewModel.showListingSheet) {
            listingSheetView
        }
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            detailRow("Type", viewModel.currentBuilding.type.rawValue)
            detailRow("Level", "\(viewModel.currentBuilding.level)")
            detailRow("Capacity", "\(viewModel.currentBuilding.capacity)")
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    private var mineDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Mine Details")

            VStack(alignment: .leading, spacing: 8) {
                detailRow("Resource", viewModel.currentBuilding.resourceType?.rawValue ?? "Unknown")
                detailRow("Abundance", "\(viewModel.currentBuilding.abundance ?? 0)")
                detailRow("Stability", "\(viewModel.currentBuilding.stability ?? 0)")
                detailRow("Starter Mine", (viewModel.currentBuilding.isStarterMine ?? false) ? "Yes" : "No")
                detailRow("Output Range", viewModel.formattedOutputRange())

                if viewModel.currentBuilding.isListedOnMarket == true {
                    Text("Market Status: Listed on Market")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.chipListed)
                }
            }
            .padding(AppTheme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .themedCard()
        }
    }

    private var productionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Production")

            TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(alignment: .leading, spacing: 12) {
                    detailRow("Producing", (viewModel.currentBuilding.isProducing ?? false) ? "Yes" : "No")

                    if viewModel.currentBuilding.isListedOnMarket == true {
                        Text("Production unavailable while listed on the market.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.textTertiary)
                    } else if viewModel.currentBuilding.isProducing == true {
                        if viewModel.isReadyToCollect(at: context.date) {
                            Text("Status: Ready to Collect")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppTheme.chipReady)
                            if let pendingOutputQuantity = viewModel.currentBuilding.pendingOutputQuantity,
                               pendingOutputQuantity > 0 {
                                Text("Output Ready: \(Int(pendingOutputQuantity))")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        } else if let productionEndsAt = viewModel.currentBuilding.productionEndsAt {
                            Text("Time Remaining: \(viewModel.formattedTimeRemaining(until: productionEndsAt, now: context.date))")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.textError)
                    }

                    if viewModel.isWorking {
                        ProgressView()
                            .tint(.white)
                    } else if viewModel.currentBuilding.isListedOnMarket == true {
                        Text("This mine is currently listed on the marketplace.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.textTertiary)
                    } else if viewModel.currentBuilding.isProducing == true {
                        if viewModel.isReadyToCollect(at: context.date) {
                            primaryButton("Collect Output") {
                                viewModel.collectProduction()
                            }
                        } else {
                            Text("Production is currently running.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                    } else {
                        Text("Input required: \(viewModel.productionInputSummary)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                        primaryButton("Start Production") {
                            viewModel.startProduction()
                        }
                    }
                }
                .padding(AppTheme.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .themedCard()
            }
        }
    }

    private var managementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Management")

            VStack(alignment: .leading, spacing: 12) {
                Text(String(format: "System Sell Value: $%.2f", viewModel.scrapValue()))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)

                if viewModel.currentBuilding.isListedOnMarket == true {
                    if let currentListing = viewModel.currentListing {
                        detailRow("Buy Now", String(format: "$%.2f", currentListing.buyNowPrice))
                        detailRow("Current Bid", String(format: "$%.2f", currentListing.currentBid))
                        if currentListing.currentBidderID == nil || currentListing.currentBidderID?.isEmpty == true {
                            secondaryButton("Cancel Listing") {
                                viewModel.cancelListing()
                            }
                            .disabled(viewModel.isWorking)
                        } else {
                            Text("This listing has bids and cannot be cancelled.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                    } else {
                        Text("Loading listing details...")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                } else {
                    primaryButton("List on Marketplace") {
                        viewModel.openListingSheet()
                    }
                    .disabled(viewModel.isWorking || (viewModel.currentBuilding.isProducing ?? false))

                    secondaryButton("Sell to System") {
                        viewModel.sellToSystem()
                    }
                    .disabled(viewModel.isWorking || (viewModel.currentBuilding.isProducing ?? false))
                }
            }
            .padding(AppTheme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .themedCard()
        }
    }

    private var managementSectionNonExtractor: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Management")
            Text(String(format: "System Sell Value: $%.2f", viewModel.scrapValue()))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
            secondaryButton("Sell to System") {
                viewModel.sellToSystem()
            }
            .disabled(viewModel.isWorking || (viewModel.currentBuilding.isProducing ?? false))
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    private var productionSectionNonExtractor: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Production")
            TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(alignment: .leading, spacing: 12) {
                    detailRow("Producing", (viewModel.currentBuilding.isProducing ?? false) ? "Yes" : "No")
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.textError)
                    }
                    if viewModel.isWorking {
                        ProgressView()
                            .tint(.white)
                    } else if viewModel.currentBuilding.isProducing == true {
                        if viewModel.isReadyToCollect(at: context.date) {
                            primaryButton("Collect Output") {
                                viewModel.collectProduction()
                            }
                        } else {
                            if let productionEndsAt = viewModel.currentBuilding.productionEndsAt {
                                Text("Time Remaining: \(viewModel.formattedTimeRemaining(until: productionEndsAt, now: context.date))")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                    } else {
                        Text("Input required: \(viewModel.productionInputSummary)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                        primaryButton("Start Production") {
                            viewModel.startProduction()
                        }
                    }
                }
                .padding(AppTheme.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .themedCard()
            }
        }
    }

    private var machinesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Machines")
            Text("\(viewModel.machines.count) / \(viewModel.currentBuilding.capacity) installed")
                .font(AppTheme.caption())
                .foregroundStyle(AppTheme.textTertiary)

            ForEach(viewModel.machines) { machine in
                machineCard(machine)
            }

            if viewModel.canAddMachine {
                Button {
                    viewModel.addMachine()
                } label: {
                    HStack {
                        Text("Add Machine")
                        Spacer()
                        Text(String(format: "$%.0f", viewModel.addMachineCost))
                            .font(AppTheme.captionMedium())
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(AppTheme.cardPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .themedCard()
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isWorking)
            }

            if viewModel.canUpgradeBuilding {
                VStack(alignment: .leading, spacing: 6) {
                    Button {
                        viewModel.upgradeBuildingLevel()
                    } label: {
                        Text("Upgrade Building (Level \(viewModel.currentBuilding.level) → \(viewModel.currentBuilding.level + 1))")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppTheme.accent.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isWorking)
                    Text("Requires: \(UpgradeCatalog.buildingUpgradeRequirementLabel(forLevel: viewModel.currentBuilding.level))")
                        .font(AppTheme.caption())
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }
        }
    }

    private func machineCard(_ machine: Machine) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(machine.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                if viewModel.isExtractor {
                    if let a = machine.abundance, let s = machine.stability {
                        Text("A:\(a) S:\(s)")
                            .font(AppTheme.caption())
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                } else if let out = machine.outputValuePerCycle {
                    Text(String(format: "%.1f/cycle", out))
                        .font(AppTheme.caption())
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            if viewModel.isExtractor {
                detailRow("Abundance", "\(machine.abundance ?? 0)")
                detailRow("Stability", "\(machine.stability ?? 0)")
            } else {
                detailRow("Output/cycle", String(format: "%.1f", machine.outputValuePerCycle ?? Machine.defaultOutputValuePerCycle))
            }
            detailRow("Upgrade level", "\(machine.level)")
            if viewModel.canUpgradeMachine(machine) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Upgrade: \(UpgradeCatalog.machineUpgradeRequirementLabel(for: viewModel.currentBuilding.type))")
                        .font(AppTheme.caption())
                        .foregroundStyle(AppTheme.textTertiary)
                    Button("Upgrade") {
                        viewModel.upgradeMachine(machine)
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .disabled(viewModel.isWorking)
                }
            }
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    private var seedFirestoreSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Testing")
            Button {
                viewModel.seedInventoryForTesting()
            } label: {
                Text("Seed Firestore (5 of each resource)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AppTheme.surfaceAlt)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isWorking)
        }
    }

    private var listingSheetView: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                Form {
                    Section("Set Buy Now Price") {
                        TextField("Enter buy now price", text: $viewModel.buyNowPriceText)
                            .keyboardType(.decimalPad)
                        Text("Resource: \(viewModel.currentBuilding.resourceType?.rawValue ?? "Unknown")")
                        Text("Abundance: \(viewModel.currentBuilding.abundance ?? 0)")
                        Text("Stability: \(viewModel.currentBuilding.stability ?? 0)")
                        Text("Level: \(viewModel.currentBuilding.level)")
                        if let pricing = viewModel.suggestedPricing() {
                            Text(String(format: "Suggested Starting Bid: $%.2f", pricing.startingBid))
                            Text(String(format: "Suggested Buy Now Range: $%.2f - $%.2f", pricing.suggestedBuyNowLow, pricing.suggestedBuyNowHigh))
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let errorMessage = viewModel.errorMessage {
                        Section {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("List Mine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.cardBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        viewModel.closeListingSheet()
                    }
                    .foregroundStyle(AppTheme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("List") {
                        viewModel.listOwnedMine()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.chipReady)
                    .disabled(viewModel.isWorking)
                }
            }
            .overlay {
                if viewModel.isWorking {
                    ProgressView("Listing...")
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - Shared components

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(AppTheme.textPrimary)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.textTertiary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppTheme.chipReady)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppTheme.cardBackgroundAlt)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        BuildingDetailView(
            userID: "demo-user-id-12345",
            building: Building(
                id: "building-starter-gold-mine",
                name: "Starter Gold Mine",
                type: .mine,
                level: 1,
                capacity: 1,
                slotIndex: 1,
                resourceType: .gold,
                abundance: 50,
                stability: 55,
                isStarterMine: true,
                isProducing: false,
                productionStartedAt: nil,
                productionEndsAt: nil,
                pendingOutputQuantity: nil,
                isListedOnMarket: false,
                marketListingID: nil
            )
        )
    }
}
