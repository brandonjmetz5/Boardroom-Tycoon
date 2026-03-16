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
                    heroSection
                    if viewModel.isExtractor {
                        mineStatsSection
                    }
                    buildingUpgradeSection
                    productionSection
                    managementSection
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

    // MARK: - Hero

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.currentBuilding.type.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                        .textCase(.uppercase)
                    labelValue("Level", "\(viewModel.currentBuilding.level)")
                    Text("Throughput ×\(String(format: "%.2f", viewModel.throughputMultiplier))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
            }
            .padding(AppTheme.cardPadding)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(colors: [AppTheme.accent.opacity(0.4), AppTheme.accent.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                )
    )}

    private func labelValue(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text("\(label):")
                .foregroundStyle(AppTheme.textTertiary)
            Text(value)
                .foregroundStyle(AppTheme.textPrimary)
        }
    }

    // MARK: - Mine stats (extractors only)

    private var mineStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Resource", icon: "cube.fill")
            VStack(alignment: .leading, spacing: 10) {
                detailRow("Resource", viewModel.currentBuilding.resourceType?.rawValue ?? "—")
                detailRow("Abundance", "\(viewModel.currentBuilding.abundance ?? 0)")
                detailRow("Stability", "\(viewModel.currentBuilding.stability ?? 0)")
                detailRow("Output range", viewModel.formattedOutputRange())
                if viewModel.currentBuilding.isListedOnMarket == true {
                    HStack(spacing: 6) {
                        Circle().fill(AppTheme.chipListed).frame(width: 8, height: 8)
                        Text("Listed on market")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.chipListed)
                    }
                }
            }
            .padding(AppTheme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .themedCard()
        }
    }

    // MARK: - Building upgrade (level + capacity)

    private var buildingUpgradeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Building upgrade", icon: "building.2.fill")
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Level \(viewModel.currentBuilding.level)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    if viewModel.currentBuilding.level < BuildingService.maxBuildingLevel {
                        Text("→")
                            .foregroundStyle(AppTheme.textTertiary)
                        Text("Level \(viewModel.currentBuilding.level + 1)")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppTheme.accent)
                    }
                    Spacer()
                }
                if viewModel.canUpgradeBuilding {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Requires: \(UpgradeCatalog.buildingUpgradeRequirementLabel(forLevel: viewModel.currentBuilding.level)) + $\(Int(viewModel.upgradeCashCost))")
                            .font(AppTheme.caption())
                            .foregroundStyle(AppTheme.textTertiary)
                        Button {
                            viewModel.upgradeBuildingLevel()
                        } label: {
                            Text("Upgrade building")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(AppTheme.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isWorking)
                    }
                } else if viewModel.currentBuilding.level >= BuildingService.maxBuildingLevel {
                    Text("Max level")
                        .font(AppTheme.caption())
                        .foregroundStyle(AppTheme.chipReady)
                }
            }
            .padding(AppTheme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .themedCard()
        }
    }

    // MARK: - Production (one Start all / Collect all)

    private var productionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Production", icon: "gearshape.2.fill")
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.currentBuilding.isListedOnMarket == true {
                    Text("Unavailable while listed on market.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.textTertiary)
                        .padding(.vertical, 8)
                } else {
                    if viewModel.recipes.count > 1 {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Recipe")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppTheme.textTertiary)
                            Picker("Recipe", selection: Binding(
                                get: { viewModel.selectedRecipeForBuilding?.id ?? "" },
                                set: { newId in viewModel.selectedRecipeForBuilding = viewModel.recipes.first(where: { $0.id == newId }) ?? viewModel.recipes.first }
                            )) {
                                ForEach(viewModel.recipes) { r in
                                    Text(r.name).tag(r.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(AppTheme.accent)
                        }
                    }

                    let scaledInputs = viewModel.scaledInputsForDisplay()
                    if !scaledInputs.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Inputs needed (Level \(viewModel.currentBuilding.level) throughput)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.textTertiary)
                            ForEach(Array(scaledInputs.enumerated()), id: \.offset) { _, item in
                                inputOutputRow(
                                    name: item.name,
                                    needed: item.needed,
                                    have: viewModel.inventoryQuantity(for: item.itemId),
                                    isInput: true
                                )
                            }
                            Text("Output per cycle")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.textTertiary)
                                .padding(.top, 4)
                            if let outQty = viewModel.scaledOutputQuantityForDisplay(), let outName = viewModel.scaledOutputItemName() {
                                inputOutputRow(
                                    name: outName,
                                    needed: nil,
                                    have: outQty,
                                    isInput: false
                                )
                            } else if viewModel.isExtractor {
                                Text("Output: Raw \(viewModel.currentBuilding.resourceType?.rawValue ?? "resource") (variable)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.textError)
                    }

                    if viewModel.isWorking {
                        ProgressView()
                            .tint(AppTheme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    } else if viewModel.isReadyToCollect(at: Date()) {
                        Button {
                            viewModel.collectProduction()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Collect")
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.chipReady)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    } else if viewModel.currentBuilding.isProducing == true, let nextEnd = viewModel.nextProductionEndTime() {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text("Ready in: \(viewModel.formattedTimeRemaining(until: nextEnd, now: context.date))")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(AppTheme.chipProducing)
                        }
                    } else if viewModel.canStartProduction {
                        Button {
                            viewModel.startProduction()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                Text("Start production")
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    } else if !viewModel.canStartProduction && viewModel.currentBuilding.isProducing != true {
                        Text("Need more resources to start production.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                }
            }
            .padding(AppTheme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .themedCard()
        }
    }

    private func inputOutputRow(name: String, needed: Double?, have: Double, isInput: Bool) -> some View {
        HStack(spacing: 10) {
            resourcePlaceholderIcon(name: name)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                if isInput, let need = needed {
                    Text("have \(formatQty(have)) · need \(formatQty(need))")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(have >= need ? AppTheme.chipReady : AppTheme.textError)
                }
            }
            Spacer()
            if let need = needed, isInput {
                Text("\(formatQty(have))/\(formatQty(need))")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(have >= need ? AppTheme.textSecondary : AppTheme.textError)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(AppTheme.surfaceAlt.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func resourcePlaceholderIcon(name: String) -> some View {
        ZStack {
            Circle()
                .fill(AppTheme.accent.opacity(0.25))
                .frame(width: 36, height: 36)
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.accent)
        }
    }

    private func formatQty(_ q: Double) -> String {
        q.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(q))" : String(format: "%.1f", q)
    }

    // MARK: - Management

    private var managementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Management", icon: "dollarsign.circle.fill")
            VStack(alignment: .leading, spacing: 12) {
                Text(String(format: "System sell value: $%.2f", viewModel.scrapValue()))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)

                if viewModel.currentBuilding.isListedOnMarket == true {
                    if let listing = viewModel.currentListing {
                        detailRow("Buy now", String(format: "$%.2f", listing.buyNowPrice))
                        detailRow("Current bid", String(format: "$%.2f", listing.currentBid))
                        if listing.currentBidderID == nil || listing.currentBidderID?.isEmpty == true {
                            Button("Cancel listing") { viewModel.cancelListing() }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                                .disabled(viewModel.isWorking)
                        }
                    }
                } else {
                    if viewModel.isExtractor {
                        Button("List on marketplace") { viewModel.openListingSheet() }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)
                            .disabled(viewModel.isWorking || viewModel.currentBuilding.isProducing == true)
                    }
                    Button("Sell to system") { viewModel.sellToSystem() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textError)
                        .disabled(viewModel.isWorking || viewModel.currentBuilding.isProducing == true)
                }
            }
            .padding(AppTheme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .themedCard()
        }
    }

    private var seedFirestoreSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Testing", icon: "wand.and.stars")
            Button {
                viewModel.seedInventoryForTesting()
            } label: {
                Text("Seed Firestore (5 of each resource)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.surfaceAlt)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isWorking)
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
        }
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

    // MARK: - Listing sheet

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
                    Button("Cancel") { viewModel.closeListingSheet() }
                        .foregroundStyle(AppTheme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("List") { viewModel.listOwnedMine() }
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
