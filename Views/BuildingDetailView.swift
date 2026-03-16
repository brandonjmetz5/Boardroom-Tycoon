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
            .padding(.horizontal, AppTheme.cardPadding)
            .padding(.top, AppTheme.cardPadding)

            // Inline building upgrade controls
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    if viewModel.currentBuilding.level < BuildingService.maxBuildingLevel {
                        Text("Upgrade to Level \(viewModel.currentBuilding.level + 1)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                    } else {
                        Text("Max level reached")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.chipReady)
                    }
                    Spacer()
                }

                if viewModel.canUpgradeBuilding {
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Requires")
                                .font(AppTheme.captionMedium())
                                .foregroundStyle(AppTheme.textTertiary)

                            // Material icons with quantities
                            let reqs = UpgradeCatalog.buildingUpgradeRequirement(forLevel: viewModel.currentBuilding.level)
                            HStack(spacing: 8) {
                                ForEach(reqs, id: \.itemID) { item in
                                    ZStack(alignment: .bottomTrailing) {
                                        resourceIconView(name: upgradeItemDisplayName(for: item.itemID))
                                        Text("\(Int(item.quantity))")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.white)
                                            .padding(3)
                                            .background(
                                                Circle()
                                                    .fill(Color.black.opacity(0.7))
                                            )
                                            .offset(x: 3, y: 3)
                                    }
                                }
                            }

                            Text(String(format: "Cash: $%.0f", viewModel.upgradeCashCost))
                                .font(AppTheme.caption())
                                .foregroundStyle(AppTheme.textSecondary)
                        }

                        Spacer()

                        Button {
                            viewModel.upgradeBuildingLevel()
                        } label: {
                            Text("Upgrade")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 18)
                                .background(
                                    LinearGradient(
                                        colors: [AppTheme.accent, AppTheme.accent.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isWorking)
                    }
                }
            }
            .padding(.horizontal, AppTheme.cardPadding)
            .padding(.bottom, AppTheme.cardPadding)
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
                HStack(spacing: 10) {
                let resourceName = viewModel.currentBuilding.resourceType?.rawValue ?? "—"
                    resourceIconView(name: resourceName)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Resource")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.textTertiary)
                        Text(resourceName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                }
                detailRow("Abundance", "\(viewModel.currentBuilding.abundance ?? 0)")
                detailRow("Output per cycle", viewModel.formattedOutputPerCycle())
                if let nextOutput = viewModel.formattedOutputAtNextLevel() {
                    detailRow("At Level \(viewModel.currentBuilding.level + 1)", nextOutput)
                        .foregroundStyle(AppTheme.accent.opacity(0.9))
                }
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
        EmptyView()
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

                    if viewModel.recipes.isEmpty == false && viewModel.isExtractor == false {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Output Quality")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppTheme.textTertiary)
                            Picker("Quality", selection: $viewModel.selectedOutputQuality) {
                                ForEach(1...max(viewModel.maxOutputQuality, 1), id: \.self) { q in
                                    Text("Q\(q)").tag(q)
                                }
                            }
                            .pickerStyle(.segmented)
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
                                Text("Output: \(viewModel.formattedOutputPerCycle()) Raw \(viewModel.currentBuilding.resourceType?.rawValue ?? "resource")")
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
            resourceIconView(name: name)
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

    @ViewBuilder
    private func resourceIconView(name: String) -> some View {
        if let assetName = resourceAssetName(for: name) {
            ZStack {
                Circle()
                    .fill(AppTheme.surfaceAlt.opacity(0.95))
                    .frame(width: 52, height: 52)
                Image(assetName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
            }
        } else {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.25))
                    .frame(width: 52, height: 52)
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
            }
        }
    }

    /// Map display names to ResourceIcons asset names.
    private func resourceAssetName(for name: String) -> String? {
        let key = name.lowercased()

        // Raw resources
        if key.contains("raw gold") { return "icon_raw_gold" }
        if key.contains("raw silver") { return "icon_raw_silver" }
        if key.contains("raw diamonds") || key == "diamond" { return "icon_raw_diamond" }
        if key.contains("raw coal") { return "icon_raw_coal" }
        if key.contains("raw iron") { return "icon_raw_iron" }
        if key.contains("crude oil") || key.contains("raw oil") || key == "oil" { return "icon_raw_oil" }
        if key.contains("sand quarry") || key == "sand" { return "icon_sand" }
        if key.contains("stone quarry") || key == "stone" || key.contains("quarry") { return "icon_stone" }
        if key.contains("gravel quarry") || key == "gravel" { return "icon_gravel" }

        // Fuels & intermediates
        if key.contains("fuel cell") { return "icon_fuel_cell" }
        if key.contains("machinery fuel pack") { return "icon_machinery_fuel_pack" }
        if key.contains("gasoline") { return "icon_gasoline" }
        if key.contains("diesel") { return "icon_diesel" }
        if key.contains("processed coal") { return "icon_processed_coal" }
        if key.contains("industrial heat block") || key.contains("industrial heat") { return "icon_industrial_heat_block" }

        // Metals / building materials
        if key.contains("steel beam") { return "icon_steel_beam" }
        if key == "steel" { return "icon_steel" }
        if key.contains("iron bar") { return "icon_iron_bar" }
        if key == "glass" { return "icon_glass" }
        if key == "brick" || key.contains("bricks") { return "icon_brick" }
        if key.contains("concrete mix") { return "icon_concrete_mix" }
        if key == "foundation" || key.contains("foundations") { return "icon_foundation" }
        if key == "window" || key.contains("windows") { return "icon_window" }
        if key == "walls" { return "icon_brick_wall" }

        // Precious outputs & jewelry
        if key == "gold bar" || key.contains("gold bars") { return "icon_gold_bar" }
        if key == "silver bar" || key.contains("silver bars") { return "icon_silver_bar" }
        if key.contains("cut diamond") { return "icon_cut_diamond" }
        if key.contains("diamond dust") { return "icon_diamond_dust" }
        if key.contains("diamond drill bit") { return "icon_diamond_drill_bit" }
        if key.contains("precision cutting head") { return "icon_precision_cutting_head" }

        if key.contains("heat sink") || key.contains("heatsink") { return "icon_heat_sink" }
        if key == "microchip" || key.contains("microchips") { return "icon_microchip" }
        if key.contains("machine computer") || key.contains("machine computers") { return "icon_machine_computer" }
        if key.contains("machine gear") || key.contains("machine gears") { return "icon_machine_gear" }
        if key.contains("robotic machine arm") || key.contains("robotic machine arms") { return "icon_robotic_machine_arm" }

        if key.contains("gold ring") || key.contains("gold rings") { return "icon_gold_ring" }
        if key.contains("silver ring") || key.contains("silver rings") { return "icon_silver_ring" }
        if key.contains("gold watch") || key.contains("gold watches") { return "icon_gold_watch" }
        if key.contains("silver watch") || key.contains("silver watches") { return "icon_silver_watch" }
        if key.contains("luxury ring") || key.contains("luxury rings") { return "icon_luxury_ring" }
        if key.contains("luxury watch") || key.contains("luxury watches") { return "icon_luxury_watch" }

        return nil
    }

    /// Display name for upgrade items based on their ID, used for hero upgrade icons.
    private func upgradeItemDisplayName(for itemID: String) -> String {
        switch itemID {
        case "foundation": return "Foundation"
        case "walls": return "Walls"
        case "window": return "Window"
        case "steel-beams", "steel_beams": return "Steel Beams"
        default: return itemID.replacingOccurrences(of: "-", with: " ").capitalized
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
