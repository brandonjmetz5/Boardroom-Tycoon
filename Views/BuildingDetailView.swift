//
//  BuildingDetailView.swift
//  Boardroom Tycoon
//
//  Industrial command-center redesign for building operations.
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
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    commandHeaderPanel
                    liveCyclePanel
                    if viewModel.isExtractor { extractorTelemetryPanel }
                    productionCommandPanel
                    assetActionsPanel
                    testingPanel
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
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
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

    // MARK: - Command panels

    private var commandHeaderPanel: some View {
        BuildingPanel(title: "Building Command", icon: "building.2.crop.circle.fill", tone: .priority) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.currentBuilding.type.rawValue.uppercased())
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppTheme.accent)
                        Text("LEVEL \(viewModel.currentBuilding.level)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppTheme.textTertiary)
                        Text("Throughput x\(NumberFormatting.decimal(viewModel.throughputMultiplier, fractionDigits: 2))")
                            .font(AppTheme.caption())
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    statusTag(title: statusSummaryText, color: statusSummaryColor)
                }

                if viewModel.currentBuilding.level < BuildingService.maxBuildingLevel {
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Upgrade to Level \(viewModel.currentBuilding.level + 1)")
                                .font(AppTheme.captionMedium())
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Cash Requirement: \(NumberFormatting.currency(viewModel.upgradeCashCost, fractionDigits: 0))")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppTheme.textSecondary)
                            upgradeRequirementIcons
                        }
                        Spacer()
                        Button("Upgrade") { viewModel.upgradeBuildingLevel() }
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.accent))
                            .buttonStyle(.plain)
                            .disabled(viewModel.isWorking || !viewModel.canUpgradeBuilding)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.surfaceAlt.opacity(0.5)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border, lineWidth: 1))
                } else {
                    Text("Maximum level reached.")
                        .font(AppTheme.captionMedium())
                        .foregroundStyle(AppTheme.chipReady)
                }
            }
        }
    }

    private var upgradeRequirementIcons: some View {
        let reqs = UpgradeCatalog.buildingUpgradeRequirement(forLevel: viewModel.currentBuilding.level)
        return HStack(spacing: 8) {
            ForEach(reqs, id: \.itemID) { item in
                ZStack(alignment: .bottomTrailing) {
                    resourceIconView(name: upgradeItemDisplayName(for: item.itemID), size: 32)
                    Text(NumberFormatting.integer(Int(item.quantity)))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(3)
                        .background(Circle().fill(Color.black.opacity(0.72)))
                        .offset(x: 3, y: 3)
                }
            }
        }
    }

    private var liveCyclePanel: some View {
        BuildingPanel(title: "Cycle Monitor", icon: "waveform.path.ecg") {
            VStack(alignment: .leading, spacing: 10) {
                if viewModel.isWorking || viewModel.isBuyingMissing {
                    HStack(spacing: 8) {
                        ProgressView().tint(AppTheme.accent)
                        Text(viewModel.isBuyingMissing ? "Acquiring missing inputs..." : "Executing command...")
                            .font(AppTheme.caption())
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    errorStrip(errorMessage)
                }
                if let buyMissingErrorMessage = viewModel.buyMissingErrorMessage {
                    errorStrip(buyMissingErrorMessage)
                }

                if viewModel.currentBuilding.isListedOnMarket == true {
                    Text("Production lock active while building is listed on market.")
                        .font(AppTheme.captionMedium())
                        .foregroundStyle(AppTheme.chipListed)
                } else if viewModel.isReadyToCollect(at: Date()) {
                    Button {
                        viewModel.collectProduction()
                    } label: {
                        commandAction(title: "Collect Output", icon: "shippingbox.fill", color: AppTheme.chipReady)
                    }
                    .buttonStyle(.plain)
                } else if viewModel.currentBuilding.isProducing == true, let nextEnd = viewModel.nextProductionEndTime() {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        HStack(spacing: 8) {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(AppTheme.chipProducing)
                            Text("Cycle ETA: \(viewModel.formattedTimeRemaining(until: nextEnd, now: context.date))")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppTheme.chipProducing)
                        }
                    }
                } else if viewModel.canStartProduction {
                    Button {
                        viewModel.startProduction()
                    } label: {
                        commandAction(title: "Start Production Cycle", icon: "play.fill", color: AppTheme.accent)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Insufficient inputs for selected quality target.")
                        .font(AppTheme.captionMedium())
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }
        }
    }

    private var extractorTelemetryPanel: some View {
        BuildingPanel(title: "Extractor Telemetry", icon: "mountain.2.fill") {
            VStack(spacing: 8) {
                let resourceName = viewModel.currentBuilding.resourceType?.rawValue ?? "Unknown"
                telemetryRow(label: "RESOURCE", value: resourceName.uppercased())
                telemetryRow(label: "ABUNDANCE", value: "\(viewModel.currentBuilding.abundance ?? 0)")
                telemetryRow(label: "OUTPUT / CYCLE", value: viewModel.formattedOutputPerCycle())
                if let next = viewModel.formattedOutputAtNextLevel() {
                    telemetryRow(label: "NEXT LEVEL", value: next, tint: AppTheme.accent)
                }
            }
        }
    }

    private var productionCommandPanel: some View {
        BuildingPanel(title: "Production Deck", icon: "gearshape.2.fill", tone: .priority) {
            VStack(alignment: .leading, spacing: 12) {
                if (viewModel.recipes.isEmpty == false && !viewModel.isExtractor) || (viewModel.isExtractor && viewModel.maxOutputQuality > 1) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Output Quality Target")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppTheme.textTertiary)
                        Picker("Quality", selection: $viewModel.selectedOutputQuality) {
                            ForEach(1...max(viewModel.maxOutputQuality, 1), id: \.self) { q in
                                Text("Q\(q)").tag(q)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                if viewModel.isExtractor {
                    extractorRecipeCard
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.recipes) { recipe in
                            recipeCommandCard(recipe)
                        }
                    }
                }
            }
        }
    }

    private var extractorRecipeCard: some View {
        let fuelTuple = viewModel.scaledInputsForDisplay().first
        let fuelNeed = fuelTuple?.needed ?? 0
        let fuelDocID = fuelTuple?.itemId ?? ""
        let fuelHave = viewModel.inventoryQuantity(for: fuelDocID)
        let missing = max(0, fuelNeed - fuelHave)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                resourceIconView(name: outputDisplayName(), size: 66)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Extraction Cycle")
                        .font(AppTheme.titleSmall())
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Output: \(viewModel.formattedOutputPerCycle())")
                        .font(AppTheme.caption())
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                resourceIconView(name: fuelTuple?.name ?? "Fuel Cells", size: 54)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fuel Status")
                        .font(AppTheme.captionMedium())
                        .foregroundStyle(AppTheme.textTertiary)
                    Text("\(formatQty(fuelHave)) / \(formatQty(fuelNeed))")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(missing > 0 ? AppTheme.chipNegative : AppTheme.chipReady)
                }
                Spacer()
            }

            if missing > 0.0000001 {
                Button {
                    viewModel.buyMissingForExtractorFuel()
                } label: {
                    commandAction(title: "Buy Missing Fuel", icon: "cart.fill.badge.plus", color: AppTheme.accent)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isWorking || viewModel.isBuyingMissing || viewModel.currentBuilding.isProducing == true)
            } else {
                statusTag(title: "FUEL READY", color: AppTheme.chipReady)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.surfaceAlt.opacity(0.55)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border, lineWidth: 1))
    }

    private func recipeCommandCard(_ recipe: Recipe) -> some View {
        let inputs = viewModel.scaledInputs(for: recipe)
        let selected = viewModel.selectedRecipeForBuilding?.id == recipe.id
        let output = viewModel.scaledOutput(for: recipe)
        let hasMissing = inputs.contains { $0.missingQty > 0.0000001 }

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                if let output {
                    resourceIconView(name: output.name, size: 62)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.name)
                        .font(AppTheme.titleSmall())
                        .foregroundStyle(AppTheme.textPrimary)
                    if let output {
                        Text("Output \(formatQty(output.qty)) / cycle")
                            .font(AppTheme.caption())
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                Spacer()
                statusTag(
                    title: hasMissing ? "INPUT GAP" : "READY",
                    color: hasMissing ? AppTheme.chipNegative : AppTheme.chipReady
                )
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(inputs) { line in
                        VStack(alignment: .leading, spacing: 6) {
                            resourceIconView(name: line.name, size: 42)
                            Text(line.name)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)
                                .lineLimit(1)
                            Text("\(formatQty(line.haveQty))/\(formatQty(line.neededQty))")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(line.missingQty > 0 ? AppTheme.chipNegative : AppTheme.textSecondary)
                        }
                        .padding(8)
                        .frame(width: 112, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.surfaceAlt.opacity(0.5)))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border, lineWidth: 1))
                    }
                }
            }

            if hasMissing {
                Button {
                    viewModel.buyMissing(for: recipe)
                } label: {
                    commandAction(title: "Buy Missing Inputs", icon: "cart.fill.badge.plus", color: AppTheme.accent)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isWorking || viewModel.isBuyingMissing || viewModel.currentBuilding.isProducing == true)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.surfaceAlt.opacity(0.55)))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(selected ? AppTheme.accent.opacity(0.8) : AppTheme.border, lineWidth: selected ? 2 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture { viewModel.selectedRecipeForBuilding = recipe }
    }

    private var assetActionsPanel: some View {
        BuildingPanel(title: "Asset Control", icon: "dollarsign.circle.fill") {
            VStack(alignment: .leading, spacing: 10) {
                telemetryRow(label: "SYSTEM SALE VALUE", value: NumberFormatting.currency(viewModel.scrapValue(), fractionDigits: 2))

                if viewModel.currentBuilding.isListedOnMarket == true {
                    if let listing = viewModel.currentListing {
                        telemetryRow(label: "BUY NOW", value: NumberFormatting.currency(listing.buyNowPrice, fractionDigits: 2))
                        telemetryRow(label: "CURRENT BID", value: NumberFormatting.currency(listing.currentBid, fractionDigits: 2))
                        if listing.currentBidderID == nil || listing.currentBidderID?.isEmpty == true {
                            Button {
                                viewModel.cancelListing()
                            } label: {
                                commandAction(title: "Cancel Listing", icon: "xmark.circle.fill", color: AppTheme.chipNegative)
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.isWorking)
                        }
                    } else {
                        Text("Listing data pending sync.")
                            .font(AppTheme.caption())
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                } else {
                    if viewModel.isExtractor {
                        Button {
                            viewModel.openListingSheet()
                        } label: {
                            commandAction(title: "List on Marketplace", icon: "tag.fill", color: AppTheme.chipListed)
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isWorking || viewModel.currentBuilding.isProducing == true)
                    }

                    Button {
                        viewModel.sellToSystem()
                    } label: {
                        commandAction(title: "Sell to System", icon: "banknote.fill", color: AppTheme.chipNegative)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isWorking || viewModel.currentBuilding.isProducing == true)
                }
            }
        }
    }

    private var testingPanel: some View {
        BuildingPanel(title: "Testing Utilities", icon: "wrench.and.screwdriver.fill") {
            Button {
                viewModel.seedInventoryForTesting()
            } label: {
                commandAction(title: "Seed Inventory (5 Each)", icon: "shippingbox.and.arrow.backward", color: AppTheme.textSecondary)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isWorking)
        }
    }

    // MARK: - Listing sheet

    private var listingSheetView: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        BuildingPanel(title: "Market Listing", icon: "tag.fill", tone: .priority) {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Buy Now Price")
                                        .font(AppTheme.captionMedium())
                                        .foregroundStyle(AppTheme.textTertiary)
                                    Spacer()
                                }

                                TextField("Enter price", text: $viewModel.buyNowPriceText)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .padding(12)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.surfaceAlt.opacity(0.5)))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border, lineWidth: 1))

                                telemetryRow(label: "RESOURCE", value: viewModel.currentBuilding.resourceType?.rawValue ?? "Unknown")
                                telemetryRow(label: "ABUNDANCE", value: "\(viewModel.currentBuilding.abundance ?? 0)")
                                telemetryRow(label: "LEVEL", value: "\(viewModel.currentBuilding.level)")

                                if let pricing = viewModel.suggestedPricing() {
                                    telemetryRow(label: "SUGGESTED BID", value: NumberFormatting.currency(pricing.startingBid, fractionDigits: 2))
                                    telemetryRow(
                                        label: "SUGGESTED BUY NOW",
                                        value: "\(NumberFormatting.currency(pricing.suggestedBuyNowLow, fractionDigits: 2)) - \(NumberFormatting.currency(pricing.suggestedBuyNowHigh, fractionDigits: 2))",
                                        tint: AppTheme.textSecondary
                                    )
                                }
                            }
                        }

                        if let errorMessage = viewModel.errorMessage {
                            errorStrip(errorMessage)
                        }
                    }
                    .padding(.horizontal, AppTheme.horizontalPadding)
                    .padding(.top, 14)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("List Mine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { viewModel.closeListingSheet() }
                        .foregroundStyle(AppTheme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("List") { viewModel.listOwnedMine() }
                        .fontWeight(.bold)
                        .foregroundStyle(AppTheme.chipReady)
                        .disabled(viewModel.isWorking)
                }
            }
            .overlay {
                if viewModel.isWorking {
                    ProgressView("Listing...")
                        .padding(20)
                        .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border, lineWidth: 1))
                }
            }
        }
    }

    // MARK: - Shared helpers

    private var statusSummaryText: String {
        if viewModel.currentBuilding.isListedOnMarket == true { return "LISTED" }
        if viewModel.isReadyToCollect(at: Date()) { return "READY" }
        if viewModel.currentBuilding.isProducing == true { return "PRODUCING" }
        return "IDLE"
    }

    private var statusSummaryColor: Color {
        if viewModel.currentBuilding.isListedOnMarket == true { return AppTheme.chipListed }
        if viewModel.isReadyToCollect(at: Date()) { return AppTheme.chipReady }
        if viewModel.currentBuilding.isProducing == true { return AppTheme.chipProducing }
        return AppTheme.chipIdle
    }

    private func statusTag(title: String, color: Color) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(color.opacity(0.95)))
    }

    private func telemetryRow(label: String, value: String, tint: Color = AppTheme.textPrimary) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.textTertiary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(tint)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.surfaceAlt.opacity(0.45)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border, lineWidth: 1))
    }

    private func commandAction(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
            Text(title)
                .font(.system(size: 14, weight: .bold))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(RoundedRectangle(cornerRadius: 10).fill(color))
    }

    private func errorStrip(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppTheme.chipNegative)
            Text(text)
                .font(AppTheme.caption())
                .foregroundStyle(AppTheme.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.surfaceAlt.opacity(0.45)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.chipNegative.opacity(0.4), lineWidth: 1))
    }

    private func outputDisplayName() -> String {
        switch viewModel.currentBuilding.resourceType {
        case .gold: return "Raw Gold"
        case .silver: return "Raw Silver"
        case .diamond: return "Raw Diamonds"
        case .oil: return "Crude Oil"
        case .coal: return "Raw Coal"
        case .iron: return "Raw Iron"
        case .quarry, .stoneQuarry: return "Raw Stone"
        case .sandQuarry: return "Raw Sand"
        case .gravelQuarry: return "Raw Gravel"
        default: return "Resource"
        }
    }

    @ViewBuilder
    private func resourceIconView(name: String, size: CGFloat = 52) -> some View {
        if let assetName = resourceAssetName(for: name) {
            ZStack {
                Circle()
                    .fill(AppTheme.surfaceAlt.opacity(0.95))
                    .frame(width: size, height: size)
                Image(assetName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(width: max(1, size - 2), height: max(1, size - 2))
                    .clipShape(Circle())
            }
        } else {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.25))
                    .frame(width: size, height: size)
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: max(12, size * 0.33), weight: .bold))
                    .foregroundStyle(AppTheme.accent)
            }
        }
    }

    private func resourceAssetName(for name: String) -> String? {
        let key = name.lowercased()
        if key.contains("raw gold") { return "icon_raw_gold" }
        if key.contains("raw silver") { return "icon_raw_silver" }
        if key.contains("raw diamonds") || key == "diamond" { return "icon_raw_diamond" }
        if key.contains("raw coal") { return "icon_raw_coal" }
        if key.contains("raw iron") { return "icon_raw_iron" }
        if key.contains("crude oil") || key.contains("raw oil") || key == "oil" { return "icon_raw_oil" }
        if key.contains("sand quarry") || key == "sand" { return "icon_sand" }
        if key.contains("stone quarry") || key == "stone" || key.contains("quarry") { return "icon_stone" }
        if key.contains("gravel quarry") || key == "gravel" { return "icon_gravel" }
        if key.contains("fuel cell") { return "icon_fuel_cell" }
        if key.contains("machinery fuel pack") { return "icon_machinery_fuel_pack" }
        if key.contains("gasoline") { return "icon_gasoline" }
        if key.contains("diesel") { return "icon_diesel" }
        if key.contains("processed coal") { return "icon_processed_coal" }
        if key.contains("industrial heat block") || key.contains("industrial heat") { return "icon_industrial_heat_block" }
        if key.contains("steel beam") { return "icon_steel_beam" }
        if key == "steel" { return "icon_steel" }
        if key.contains("iron bar") { return "icon_iron_bar" }
        if key == "glass" { return "icon_glass" }
        if key == "brick" || key.contains("bricks") { return "icon_brick" }
        if key.contains("concrete mix") { return "icon_concrete_mix" }
        if key == "foundation" || key.contains("foundations") { return "icon_foundation" }
        if key == "window" || key.contains("windows") { return "icon_window" }
        if key == "walls" { return "icon_brick_wall" }
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
        q.truncatingRemainder(dividingBy: 1) == 0 ? NumberFormatting.integer(Int(q)) : NumberFormatting.decimal(q, fractionDigits: 1)
    }
}

private enum BuildingPanelTone {
    case normal
    case priority
}

private struct BuildingPanel<Content: View>: View {
    let title: String
    let icon: String
    let tone: BuildingPanelTone
    private let content: Content

    init(
        title: String,
        icon: String,
        tone: BuildingPanelTone = .normal,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.tone = tone
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(tone == .priority ? AppTheme.accent : AppTheme.textSecondary)
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)
                Rectangle().fill(AppTheme.border).frame(height: 1)
            }
            content
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(AppTheme.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(tone == .priority ? AppTheme.accent.opacity(0.45) : AppTheme.border, lineWidth: 1)
        )
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
//
//  BuildingDetailView.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/12/26.
//

//import SwiftUI
//
//struct BuildingDetailView: View {
//    let userID: String
//    let building: Building
//
//    @Environment(\.dismiss) private var dismiss
//    @StateObject private var viewModel: BuildingDetailViewModel
//
//    init(userID: String, building: Building) {
//        self.userID = userID
//        self.building = building
//        _viewModel = StateObject(wrappedValue: BuildingDetailViewModel(userID: userID, building: building))
//    }
//
//    var body: some View {
//        ZStack {
//            AppTheme.background
//                .ignoresSafeArea()
//
//            ScrollView {
//                VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
//                    heroSection
//                if viewModel.isExtractor {
//                    mineStatsSection
//                }
//                buildingUpgradeSection
//                productionSection
//                    managementSection
//                    seedFirestoreSection
//                }
//                .padding(.horizontal, AppTheme.horizontalPadding)
//                .padding(.top, 12)
//                .padding(.bottom, 24)
//            }
//        }
//        .navigationTitle("")
//        .navigationBarTitleDisplayMode(.inline)
//        .toolbar {
//            ToolbarItem(placement: .principal) {
//                Text(viewModel.currentBuilding.name)
//                    .font(.system(size: 22, weight: .semibold))
//                    .foregroundStyle(AppTheme.textPrimary)
//                    .lineLimit(1)
//                    .truncationMode(.tail)
//            }
//        }
//        .onAppear {
//            viewModel.onDismiss = { dismiss() }
//            viewModel.refreshBuilding()
//        }
//        .sheet(isPresented: $viewModel.showListingSheet) {
//            listingSheetView
//        }
//    }
//
//    // MARK: - Hero
//
//    private var heroSection: some View {
//        VStack(alignment: .leading, spacing: 12) {
//            HStack(alignment: .top) {
//                VStack(alignment: .leading, spacing: 4) {
//                    Text(viewModel.currentBuilding.type.rawValue)
//                        .font(.system(size: 12, weight: .semibold))
//                        .foregroundStyle(AppTheme.accent)
//                        .textCase(.uppercase)
//                    labelValue("Level", "\(viewModel.currentBuilding.level)")
//                    Text("Throughput ×\(String(format: "%.2f", viewModel.throughputMultiplier))")
//                        .font(.system(size: 14, weight: .medium))
//                        .foregroundStyle(AppTheme.textSecondary)
//                }
//                Spacer()
//            }
//            .padding(.horizontal, AppTheme.cardPadding)
//            .padding(.top, AppTheme.cardPadding)
//
//            // Inline building upgrade controls
//            VStack(alignment: .leading, spacing: 10) {
//                HStack {
//                    if viewModel.currentBuilding.level < BuildingService.maxBuildingLevel {
//                        Text("Upgrade to Level \(viewModel.currentBuilding.level + 1)")
//                            .font(.system(size: 14, weight: .semibold))
//                            .foregroundStyle(AppTheme.textPrimary)
//                    } else {
//                        Text("Max level reached")
//                            .font(.system(size: 14, weight: .semibold))
//                            .foregroundStyle(AppTheme.chipReady)
//                    }
//                    Spacer()
//                }
//
//                if viewModel.canUpgradeBuilding {
//                    HStack(alignment: .center, spacing: 10) {
//                        VStack(alignment: .leading, spacing: 6) {
//                            Text("Requires")
//                                .font(AppTheme.captionMedium())
//                                .foregroundStyle(AppTheme.textTertiary)
//
//                            // Material icons with quantities
//                            let reqs = UpgradeCatalog.buildingUpgradeRequirement(forLevel: viewModel.currentBuilding.level)
//                            HStack(spacing: 8) {
//                                ForEach(reqs, id: \.itemID) { item in
//                                    ZStack(alignment: .bottomTrailing) {
//                                        resourceIconView(name: upgradeItemDisplayName(for: item.itemID))
//                                        Text("\(Int(item.quantity))")
//                                            .font(.system(size: 10, weight: .bold))
//                                            .foregroundStyle(.white)
//                                            .padding(3)
//                                            .background(
//                                                Circle()
//                                                    .fill(Color.black.opacity(0.7))
//                                            )
//                                            .offset(x: 3, y: 3)
//                                    }
//                                }
//                            }
//
//                            Text(String(format: "Cash: $%.0f", viewModel.upgradeCashCost))
//                                .font(AppTheme.caption())
//                                .foregroundStyle(AppTheme.textSecondary)
//                        }
//
//                        Spacer()
//
//                        Button {
//                            viewModel.upgradeBuildingLevel()
//                        } label: {
//                            Text("Upgrade")
//                                .font(.system(size: 14, weight: .semibold))
//                                .foregroundStyle(.white)
//                                .padding(.vertical, 10)
//                                .padding(.horizontal, 18)
//                                .background(
//                                    LinearGradient(
//                                        colors: [AppTheme.accent, AppTheme.accent.opacity(0.8)],
//                                        startPoint: .leading,
//                                        endPoint: .trailing
//                                    )
//                                )
//                                .clipShape(Capsule())
//                        }
//                        .buttonStyle(.plain)
//                        .disabled(viewModel.isWorking)
//                    }
//                }
//            }
//            .padding(.horizontal, AppTheme.cardPadding)
//            .padding(.bottom, AppTheme.cardPadding)
//        }
//        .frame(maxWidth: .infinity, alignment: .leading)
//        .background(
//            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
//                .fill(AppTheme.surface)
//                .overlay(
//                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
//                        .stroke(
//                            LinearGradient(colors: [AppTheme.accent.opacity(0.4), AppTheme.accent.opacity(0.1)], //startPoint: .topLeading, endPoint: .bottomTrailing),
//                            lineWidth: 1
//                        )
//                )
//    )}
//
//    private func labelValue(_ label: String, _ value: String) -> some View {
//        HStack(spacing: 4) {
//            Text("\(label):")
//                .foregroundStyle(AppTheme.textTertiary)
//            Text(value)
//                .foregroundStyle(AppTheme.textPrimary)
//        }
//    }
//
//    // MARK: - Mine stats (extractors only)
//
//    private var mineStatsSection: some View {
//        VStack(alignment: .leading, spacing: 12) {
//            sectionHeader("Resource", icon: "cube.fill")
//            VStack(alignment: .leading, spacing: 10) {
//                HStack(spacing: 10) {
//                let resourceName = viewModel.currentBuilding.resourceType?.rawValue ?? "—"
//                    resourceIconView(name: resourceName)
//                    VStack(alignment: .leading, spacing: 2) {
//                        Text("Resource")
//                            .font(.system(size: 13, weight: .medium))
//                            .foregroundStyle(AppTheme.textTertiary)
//                        Text(resourceName)
//                            .font(.system(size: 14, weight: .medium))
//                            .foregroundStyle(AppTheme.textSecondary)
//                    }
//                    Spacer()
//                }
//                detailRow("Abundance", "\(viewModel.currentBuilding.abundance ?? 0)")
//                detailRow("Output per cycle", viewModel.formattedOutputPerCycle())
//                if let nextOutput = viewModel.formattedOutputAtNextLevel() {
//                    detailRow("At Level \(viewModel.currentBuilding.level + 1)", nextOutput)
//                        .foregroundStyle(AppTheme.accent.opacity(0.9))
//                }
//                if viewModel.currentBuilding.isListedOnMarket == true {
//                    HStack(spacing: 6) {
//                        Circle().fill(AppTheme.chipListed).frame(width: 8, height: 8)
//                        Text("Listed on market")
//                            .font(.system(size: 13, weight: .medium))
//                            .foregroundStyle(AppTheme.chipListed)
//                    }
//                }
//            }
//            .padding(AppTheme.cardPadding)
//            .frame(maxWidth: .infinity, alignment: .leading)
//            .themedCard()
//        }
//    }
//
//    // MARK: - Building upgrade (level + capacity)
//
//    private var buildingUpgradeSection: some View {
//        EmptyView()
//    }
//
//    // MARK: - Production (one Start all / Collect all)
//
//    private var productionSection: some View {
//        VStack(alignment: .leading, spacing: 12) {
//            sectionHeader("Production", icon: "gearshape.2.fill")
//            VStack(alignment: .leading, spacing: 16) {
//                if viewModel.currentBuilding.isListedOnMarket == true {
//                    Text("Unavailable while listed on market.")
//                        .font(.system(size: 13, weight: .medium))
//                        .foregroundStyle(AppTheme.textTertiary)
//                        .padding(.vertical, 8)
//                } else {
//                    if (viewModel.recipes.isEmpty == false && viewModel.isExtractor == false) || (viewModel.isExtractor && //viewModel.maxOutputQuality > 1) {
//                        VStack(alignment: .leading, spacing: 6) {
//                            Text("Output Quality")
//                                .font(.system(size: 12, weight: .medium))
//                                .foregroundStyle(AppTheme.textTertiary)
//                            Picker("Quality", selection: $viewModel.selectedOutputQuality) {
//                                ForEach(1...max(viewModel.maxOutputQuality, 1), id: \.self) { q in
//                                    Text("Q\(q)").tag(q)
//                                }
//                            }
//                            .pickerStyle(.segmented)
//                        }
//                    }
//
//                    VStack(alignment: .leading, spacing: 12) {
//                        if viewModel.isExtractor {
//                            extractorProductionCard
//                        } else {
//                            ForEach(viewModel.recipes) { r in
//                                productionRecipeCard(r)
//                            }
//                        }
//                    }
//                    .padding(.vertical, 4)
//
//                    if let errorMessage = viewModel.errorMessage {
//                        Text(errorMessage)
//                            .font(.system(size: 13, weight: .medium))
//                            .foregroundStyle(AppTheme.textError)
//                    }
//                    if let buyMissingError = viewModel.buyMissingErrorMessage {
//                        Text(buyMissingError)
//                            .font(.system(size: 13, weight: .medium))
//                            .foregroundStyle(AppTheme.textError)
//                    }
//
//                    if viewModel.isWorking || viewModel.isBuyingMissing {
//                        ProgressView()
//                            .tint(AppTheme.accent)
//                            .frame(maxWidth: .infinity)
//                            .padding(.vertical, 8)
//                    } else if viewModel.isReadyToCollect(at: Date()) {
//                        Button {
//                            viewModel.collectProduction()
//                        } label: {
//                            HStack(spacing: 8) {
//                                Image(systemName: "checkmark.circle.fill")
//                                Text("Collect")
//                            }
//                            .font(.system(size: 15, weight: .semibold))
//                            .foregroundStyle(.white)
//                            .frame(maxWidth: .infinity)
//                            .padding(.vertical, 14)
//                            .background(AppTheme.chipReady)
//                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
//                        }
//                        .buttonStyle(.plain)
//                    } else if viewModel.currentBuilding.isProducing == true, let nextEnd = //viewModel.nextProductionEndTime() {
//                        TimelineView(.periodic(from: .now, by: 1)) { context in
//                            Text("Ready in: \(viewModel.formattedTimeRemaining(until: nextEnd, now: context.date))")
//                                .font(.system(size: 14, weight: .medium))
//                                .foregroundStyle(AppTheme.chipProducing)
//                        }
//                    } else if viewModel.canStartProduction {
//                        Button {
//                            viewModel.startProduction()
//                        } label: {
//                            HStack(spacing: 8) {
//                                Image(systemName: "play.fill")
//                                Text("Start production")
//                            }
//                            .font(.system(size: 15, weight: .semibold))
//                            .foregroundStyle(.white)
//                            .frame(maxWidth: .infinity)
//                            .padding(.vertical, 14)
//                            .background(AppTheme.accent)
//                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
//                        }
//                        .buttonStyle(.plain)
//                    } else if !viewModel.canStartProduction && viewModel.currentBuilding.isProducing != true {
//                        Text("Need more resources to start production.")
//                            .font(.system(size: 13, weight: .medium))
//                            .foregroundStyle(AppTheme.textTertiary)
//                    }
//                }
//            }
//            .padding(AppTheme.cardPadding)
//            .frame(maxWidth: .infinity, alignment: .leading)
//            .themedCard()
//        }
//    }
//
//    // MARK: - Production cards (big inputs/outputs + inline buy missing)
//
//    private var extractorProductionCard: some View {
//        let fuelTuple = viewModel.scaledInputsForDisplay().first
//        let fuelNeeded = fuelTuple?.needed ?? 0
//        let fuelDocId = fuelTuple?.itemId ?? ""
//        let fuelHave = viewModel.inventoryQuantity(for: fuelDocId)
//        let missing = max(0, fuelNeeded - fuelHave)
//        let q = max(1, viewModel.selectedOutputQuality)
//
//        let outputName: String = {
//            switch viewModel.currentBuilding.resourceType {
//            case .gold: return "Raw Gold"
//            case .silver: return "Raw Silver"
//            case .diamond: return "Raw Diamonds"
//            case .oil: return "Crude Oil"
//            case .coal: return "Raw Coal"
//            case .iron: return "Raw Iron"
//            case .quarry, .stoneQuarry: return "Raw Stone"
//            case .sandQuarry: return "Raw Sand"
//            case .gravelQuarry: return "Raw Gravel"
//            default: return "Resource"
//            }
//        }()
//
//        return VStack(alignment: .leading, spacing: 12) {
//            HStack(alignment: .top, spacing: 14) {
//                resourceIconView(name: outputName, size: 76)
//
//                VStack(alignment: .leading, spacing: 4) {
//                    Text("Extraction")
//                        .font(AppTheme.titleSmall())
//                        .foregroundStyle(AppTheme.textPrimary)
//                    Text("Output per cycle: \(viewModel.formattedOutputPerCycle())")
//                        .font(AppTheme.caption())
//                        .foregroundStyle(AppTheme.textSecondary)
//
//                    if q > 1 {
//                        Text("Target Q\(q)")
//                            .font(AppTheme.captionMedium())
//                            .foregroundStyle(AppTheme.accent)
//                    }
//                }
//
//                Spacer()
//            }
//
//            HStack(alignment: .center, spacing: 14) {
//                resourceIconView(name: fuelTuple?.name ?? "Fuel Cells", size: 64)
//                VStack(alignment: .leading, spacing: 4) {
//                    Text("Fuel")
//                        .font(AppTheme.captionMedium())
//                        .foregroundStyle(AppTheme.textTertiary)
//                    Text("\(formatQty(fuelHave)) / \(formatQty(fuelNeeded))")
//                        .font(AppTheme.monoNumber())
//                        .foregroundStyle(missing > 0 ? AppTheme.chipNegative : AppTheme.chipReady)
//                    if missing > 0.0000001 {
//                        Text("Missing: \(formatQty(missing))")
//                            .font(AppTheme.caption())
//                            .foregroundStyle(AppTheme.textError)
//                    }
//                }
//                Spacer()
//            }
//
//            if missing > 0.0000001 {
//                Button {
//                    viewModel.buyMissingForExtractorFuel()
//                } label: {
//                    HStack(spacing: 8) {
//                        Image(systemName: "cart.fill")
//                        Text("Buy missing")
//                    }
//                    .font(AppTheme.bodyMedium())
//                    .foregroundStyle(.white)
//                    .frame(maxWidth: .infinity)
//                    .padding(.vertical, 12)
//                    .background(AppTheme.accent)
//                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
//                }
//                .buttonStyle(.plain)
//                .disabled(viewModel.isWorking || viewModel.isBuyingMissing || viewModel.currentBuilding.isProducing == //true)
//                .opacity(viewModel.isWorking || viewModel.isBuyingMissing || viewModel.currentBuilding.isProducing == true //? 0.7 : 1)
//            } else {
//                Text("Fuel ready")
//                    .font(AppTheme.captionMedium())
//                    .foregroundStyle(AppTheme.chipReady)
//                    .padding(.top, 4)
//            }
//        }
//        .padding(AppTheme.cardPadding)
//        .frame(maxWidth: .infinity, alignment: .leading)
//        .background(AppTheme.surfaceAlt.opacity(0.55))
//        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
//        .overlay(
//            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
//                .stroke(AppTheme.border, lineWidth: 1)
//        )
//    }
//
//    private func productionRecipeCard(_ recipe: Recipe) -> some View {
//        let inputs = viewModel.scaledInputs(for: recipe)
//        let hasMissing = inputs.contains { $0.missingQty > 0.0000001 }
//        let q = max(1, viewModel.selectedOutputQuality)
//        let selected = viewModel.selectedRecipeForBuilding?.id == recipe.id
//        let output = viewModel.scaledOutput(for: recipe)
//
//        return VStack(alignment: .leading, spacing: 12) {
//            HStack(alignment: .top, spacing: 14) {
//                if let out = output {
//                    resourceIconView(name: out.name, size: 76)
//                }
//
//                VStack(alignment: .leading, spacing: 4) {
//                    Text(recipe.name)
//                        .font(AppTheme.titleSmall())
//                        .foregroundStyle(AppTheme.textPrimary)
//
//                    if let out = output {
//                        Text("Output: \(formatQty(out.qty)) per cycle")
//                            .font(AppTheme.caption())
//                            .foregroundStyle(AppTheme.textSecondary)
//                    }
//
//                    if q > 1 {
//                        Text("Target Q\(q)")
//                            .font(AppTheme.captionMedium())
//                            .foregroundStyle(AppTheme.accent)
//                    }
//                }
//
//                Spacer()
//            }
//
//            ScrollView(.horizontal, showsIndicators: false) {
//                HStack(spacing: 16) {
//                    ForEach(inputs) { line in
//                        VStack(alignment: .leading, spacing: 8) {
//                            resourceIconView(name: line.name, size: 64)
//                                .frame(width: 64, height: 64)
//
//                            Text("\(formatQty(line.haveQty)) / \(formatQty(line.neededQty))")
//                                .font(AppTheme.captionMedium())
//                                .foregroundStyle(line.missingQty > 0.0000001 ? AppTheme.textError : AppTheme.textTertiary)
//
//                            if line.missingQty > 0.0000001 {
//                                Text("Missing \(formatQty(line.missingQty))")
//                                    .font(.system(size: 11, weight: .medium))
//                                    .foregroundStyle(AppTheme.chipNegative)
//                            }
//                        }
//                        .padding(8)
//                        .background(AppTheme.surfaceAlt.opacity(0.35))
//                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
//                    }
//                }
//            }
//
//            if hasMissing {
//                Button {
//                    viewModel.buyMissing(for: recipe)
//                } label: {
//                    HStack(spacing: 8) {
//                        Image(systemName: "cart.fill")
//                        Text("Buy missing")
//                    }
//                    .font(AppTheme.bodyMedium())
//                    .foregroundStyle(.white)
//                    .frame(maxWidth: .infinity)
//                    .padding(.vertical, 12)
//                    .background(AppTheme.accent)
//                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
//                }
//                .buttonStyle(.plain)
//                .disabled(viewModel.isWorking || viewModel.isBuyingMissing || viewModel.currentBuilding.isProducing == //true)
//                .opacity(viewModel.isWorking || viewModel.isBuyingMissing || viewModel.currentBuilding.isProducing == true //? 0.7 : 1)
//            } else {
//                HStack(spacing: 8) {
//                    Image(systemName: "checkmark.seal.fill")
//                        .foregroundStyle(AppTheme.chipReady)
//                    Text("Inputs ready")
//                        .font(AppTheme.captionMedium())
//                        .foregroundStyle(AppTheme.chipReady)
//                }
//                .padding(.top, 2)
//            }
//        }
//        .padding(AppTheme.cardPadding)
//        .frame(maxWidth: .infinity, alignment: .leading)
//        .background(AppTheme.surfaceAlt.opacity(0.55))
//        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
//        .overlay(
//            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
//                .stroke(selected ? AppTheme.accent.opacity(0.9) : AppTheme.border, lineWidth: selected ? 2 : 1)
//        )
//        .contentShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
//        .onTapGesture {
//            viewModel.selectedRecipeForBuilding = recipe
//        }
//        .buttonStyle(.plain)
//    }
//
//    private func inputOutputRow(name: String, needed: Double?, have: Double, isInput: Bool) -> some View {
//        HStack(spacing: 10) {
//            resourceIconView(name: name)
//            VStack(alignment: .leading, spacing: 2) {
//                Text(name)
//                    .font(.system(size: 14, weight: .medium))
//                    .foregroundStyle(AppTheme.textPrimary)
//                if isInput, let need = needed {
//                    Text("have \(formatQty(have)) · need \(formatQty(need))")
//                        .font(.system(size: 12, weight: .regular))
//                        .foregroundStyle(have >= need ? AppTheme.chipReady : AppTheme.textError)
//                }
//            }
//            Spacer()
//            if let need = needed, isInput {
//                Text("\(formatQty(have))/\(formatQty(need))")
//                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
//                    .foregroundStyle(have >= need ? AppTheme.textSecondary : AppTheme.textError)
//            }
//        }
//        .padding(.vertical, 6)
//        .padding(.horizontal, 10)
//        .background(AppTheme.surfaceAlt.opacity(0.6))
//        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
//    }
//
//    @ViewBuilder
//    private func resourceIconView(name: String, size: CGFloat = 52) -> some View {
//        if let assetName = resourceAssetName(for: name) {
//            ZStack {
//                Circle()
//                    .fill(AppTheme.surfaceAlt.opacity(0.95))
//                    .frame(width: size, height: size)
//                Image(assetName)
//                    .resizable()
//                    .interpolation(.high)
//                    .scaledToFill()
//                    .frame(width: max(1, size - 2), height: max(1, size - 2))
//                    .clipShape(Circle())
//            }
//        } else {
//            ZStack {
//                Circle()
//                    .fill(AppTheme.accent.opacity(0.25))
//                    .frame(width: size, height: size)
//                Text(String(name.prefix(1)).uppercased())
//                    .font(.system(size: max(12, size * 0.33), weight: .bold))
//                    .foregroundStyle(AppTheme.accent)
//            }
//        }
//    }
//
//    /// Map display names to ResourceIcons asset names.
//    private func resourceAssetName(for name: String) -> String? {
//        let key = name.lowercased()
//
//        // Raw resources
//        if key.contains("raw gold") { return "icon_raw_gold" }
//        if key.contains("raw silver") { return "icon_raw_silver" }
//        if key.contains("raw diamonds") || key == "diamond" { return "icon_raw_diamond" }
//        if key.contains("raw coal") { return "icon_raw_coal" }
//        if key.contains("raw iron") { return "icon_raw_iron" }
//        if key.contains("crude oil") || key.contains("raw oil") || key == "oil" { return "icon_raw_oil" }
//        if key.contains("sand quarry") || key == "sand" { return "icon_sand" }
//        if key.contains("stone quarry") || key == "stone" || key.contains("quarry") { return "icon_stone" }
//        if key.contains("gravel quarry") || key == "gravel" { return "icon_gravel" }
//
//        // Fuels & intermediates
//        if key.contains("fuel cell") { return "icon_fuel_cell" }
//        if key.contains("machinery fuel pack") { return "icon_machinery_fuel_pack" }
//        if key.contains("gasoline") { return "icon_gasoline" }
//        if key.contains("diesel") { return "icon_diesel" }
//        if key.contains("processed coal") { return "icon_processed_coal" }
//        if key.contains("industrial heat block") || key.contains("industrial heat") { return "icon_industrial_heat_block" }
//
//        // Metals / building materials
//        if key.contains("steel beam") { return "icon_steel_beam" }
//        if key == "steel" { return "icon_steel" }
//        if key.contains("iron bar") { return "icon_iron_bar" }
//        if key == "glass" { return "icon_glass" }
//        if key == "brick" || key.contains("bricks") { return "icon_brick" }
//        if key.contains("concrete mix") { return "icon_concrete_mix" }
//        if key == "foundation" || key.contains("foundations") { return "icon_foundation" }
//        if key == "window" || key.contains("windows") { return "icon_window" }
//        if key == "walls" { return "icon_brick_wall" }
//
//        // Precious outputs & jewelry
//        if key == "gold bar" || key.contains("gold bars") { return "icon_gold_bar" }
//        if key == "silver bar" || key.contains("silver bars") { return "icon_silver_bar" }
//        if key.contains("cut diamond") { return "icon_cut_diamond" }
//        if key.contains("diamond dust") { return "icon_diamond_dust" }
//        if key.contains("diamond drill bit") { return "icon_diamond_drill_bit" }
//        if key.contains("precision cutting head") { return "icon_precision_cutting_head" }
//
//        if key.contains("heat sink") || key.contains("heatsink") { return "icon_heat_sink" }
//        if key == "microchip" || key.contains("microchips") { return "icon_microchip" }
//        if key.contains("machine computer") || key.contains("machine computers") { return "icon_machine_computer" }
//        if key.contains("machine gear") || key.contains("machine gears") { return "icon_machine_gear" }
//        if key.contains("robotic machine arm") || key.contains("robotic machine arms") { return "icon_robotic_machine_arm" //}
//
//        if key.contains("gold ring") || key.contains("gold rings") { return "icon_gold_ring" }
//        if key.contains("silver ring") || key.contains("silver rings") { return "icon_silver_ring" }
//        if key.contains("gold watch") || key.contains("gold watches") { return "icon_gold_watch" }
//        if key.contains("silver watch") || key.contains("silver watches") { return "icon_silver_watch" }
//        if key.contains("luxury ring") || key.contains("luxury rings") { return "icon_luxury_ring" }
//        if key.contains("luxury watch") || key.contains("luxury watches") { return "icon_luxury_watch" }
//
//        return nil
//    }
//
//    /// Display name for upgrade items based on their ID, used for hero upgrade icons.
//    private func upgradeItemDisplayName(for itemID: String) -> String {
//        switch itemID {
//        case "foundation": return "Foundation"
//        case "walls": return "Walls"
//        case "window": return "Window"
//        case "steel-beams", "steel_beams": return "Steel Beams"
//        default: return itemID.replacingOccurrences(of: "-", with: " ").capitalized
//        }
//    }
//
//    private func formatQty(_ q: Double) -> String {
//        q.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(q))" : String(format: "%.1f", q)
//    }
//
//    // MARK: - Management
//
//    private var managementSection: some View {
//        VStack(alignment: .leading, spacing: 12) {
//            sectionHeader("Management", icon: "dollarsign.circle.fill")
//            VStack(alignment: .leading, spacing: 12) {
//                Text(String(format: "System sell value: $%.2f", viewModel.scrapValue()))
//                    .font(.system(size: 14, weight: .medium))
//                    .foregroundStyle(AppTheme.textSecondary)
//
//                if viewModel.currentBuilding.isListedOnMarket == true {
//                    if let listing = viewModel.currentListing {
//                        detailRow("Buy now", String(format: "$%.2f", listing.buyNowPrice))
//                        detailRow("Current bid", String(format: "$%.2f", listing.currentBid))
//                        if listing.currentBidderID == nil || listing.currentBidderID?.isEmpty == true {
//                            Button("Cancel listing") { viewModel.cancelListing() }
//                                .font(.system(size: 14, weight: .semibold))
//                                .foregroundStyle(AppTheme.textPrimary)
//                                .disabled(viewModel.isWorking)
//                        }
//                    }
//                } else {
//                    if viewModel.isExtractor {
//                        Button("List on marketplace") { viewModel.openListingSheet() }
//                            .font(.system(size: 14, weight: .semibold))
//                            .foregroundStyle(AppTheme.accent)
//                            .disabled(viewModel.isWorking || viewModel.currentBuilding.isProducing == true)
//                    }
//                    Button("Sell to system") { viewModel.sellToSystem() }
//                        .font(.system(size: 14, weight: .semibold))
//                        .foregroundStyle(AppTheme.textError)
//                        .disabled(viewModel.isWorking || viewModel.currentBuilding.isProducing == true)
//                }
//            }
//            .padding(AppTheme.cardPadding)
//            .frame(maxWidth: .infinity, alignment: .leading)
//            .themedCard()
//        }
//    }
//
//    private var seedFirestoreSection: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            sectionHeader("Testing", icon: "wand.and.stars")
//            Button {
//                viewModel.seedInventoryForTesting()
//            } label: {
//                Text("Seed Firestore (5 of each resource)")
//                    .font(.system(size: 14, weight: .medium))
//                    .foregroundStyle(AppTheme.textSecondary)
//                    .frame(maxWidth: .infinity)
//                    .padding(.vertical, 12)
//                    .background(AppTheme.surfaceAlt)
//                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
//            }
//            .buttonStyle(.plain)
//            .disabled(viewModel.isWorking)
//        }
//    }
//
//    private func sectionHeader(_ title: String, icon: String) -> some View {
//        HStack(spacing: 8) {
//            Image(systemName: icon)
//                .font(.system(size: 14, weight: .semibold))
//                .foregroundStyle(AppTheme.accent)
//            Text(title)
//                .font(.system(size: 14, weight: .semibold))
//                .foregroundStyle(AppTheme.textPrimary)
//        }
//    }
//
//    private func detailRow(_ label: String, _ value: String) -> some View {
//        HStack {
//            Text(label)
//                .font(.system(size: 13, weight: .medium))
//                .foregroundStyle(AppTheme.textTertiary)
//            Spacer()
//            Text(value)
//                .font(.system(size: 14, weight: .medium))
//                .foregroundStyle(AppTheme.textSecondary)
//        }
//    }
//
//    // MARK: - Listing sheet
//
//    private var listingSheetView: some View {
//        NavigationStack {
//            ZStack {
//                AppTheme.background.ignoresSafeArea()
//                Form {
//                    Section("Set Buy Now Price") {
//                        TextField("Enter buy now price", text: $viewModel.buyNowPriceText)
//                            .keyboardType(.decimalPad)
//                        Text("Resource: \(viewModel.currentBuilding.resourceType?.rawValue ?? "Unknown")")
//                        Text("Abundance: \(viewModel.currentBuilding.abundance ?? 0)")
//                        Text("Level: \(viewModel.currentBuilding.level)")
//                        if let pricing = viewModel.suggestedPricing() {
//                            Text(String(format: "Suggested Starting Bid: $%.2f", pricing.startingBid))
//                            Text(String(format: "Suggested Buy Now Range: $%.2f - $%.2f", pricing.suggestedBuyNowLow, //pricing.suggestedBuyNowHigh))
//                                .foregroundStyle(.secondary)
//                        }
//                    }
//                    if let errorMessage = viewModel.errorMessage {
//                        Section {
//                            Text(errorMessage)
//                                .foregroundStyle(.red)
//                        }
//                    }
//                }
//                .scrollContentBackground(.hidden)
//            }
//            .navigationTitle("List Mine")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbarBackground(AppTheme.cardBackground, for: .navigationBar)
//            .toolbarColorScheme(.dark, for: .navigationBar)
//            .toolbar {
//                ToolbarItem(placement: .topBarLeading) {
//                    Button("Cancel") { viewModel.closeListingSheet() }
//                        .foregroundStyle(AppTheme.textSecondary)
//                }
//                ToolbarItem(placement: .topBarTrailing) {
//                    Button("List") { viewModel.listOwnedMine() }
//                        .fontWeight(.semibold)
//                        .foregroundStyle(AppTheme.chipReady)
//                        .disabled(viewModel.isWorking)
//                }
//            }
//            .overlay {
//                if viewModel.isWorking {
//                    ProgressView("Listing...")
//                        .padding(24)
//                        .background(.ultraThinMaterial)
//                        .cornerRadius(12)
//                }
//            }
//        }
//    }
//}
//
//#Preview {
//    NavigationStack {
//        BuildingDetailView(
//            userID: "demo-user-id-12345",
//            building: Building(
//                id: "building-starter-gold-mine",
//                name: "Starter Gold Mine",
//                type: .mine,
//                level: 1,
//                capacity: 1,
//                slotIndex: 1,
//                resourceType: .gold,
//                abundance: 50,
//                isStarterMine: true,
//                isProducing: false,
//                productionStartedAt: nil,
//                productionEndsAt: nil,
//                pendingOutputQuantity: nil,
//                pendingOutputItemId: nil,
//                pendingOutputItemName: nil,
//                isListedOnMarket: false,
//                marketListingID: nil
//            )
//        )
//    }
//}
//
