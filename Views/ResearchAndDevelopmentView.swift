//
//  ResearchAndDevelopmentView.swift
//  Boardroom Tycoon
//
//  R&D Department — lab control center with cycle timer, categorized research projects.
//

import SwiftUI
import Combine

struct ResearchAndDevelopmentView: View {
    let userID: String
    let building: Building

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ResearchAndDevelopmentViewModel
    @State private var selectedItem: Item?
    @State private var applyPointsText = "50"

    init(userID: String, building: Building) {
        self.userID = userID
        self.building = building
        _viewModel = StateObject(wrappedValue: ResearchAndDevelopmentViewModel(userID: userID, building: building))
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView("Initializing lab...")
                    .controlSize(.large)
                    .tint(AppTheme.accent)
                    .foregroundStyle(AppTheme.textPrimary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        labHeaderSection
                        cycleControlSection
                        labUpgradeSection
                        researchProjectsSection
                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AppTheme.textError)
                                .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal, AppTheme.horizontalPadding)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Image(systemName: "flask.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(AppTheme.accent)
                    Text("R&D Lab")
                        .font(AppTheme.titleMedium())
                        .foregroundStyle(AppTheme.textPrimary)
                }
            }
        }
        .onAppear { viewModel.loadData() }
        .sheet(item: $selectedItem) { item in
            applyPointsSheet(for: item)
        }
    }

    // MARK: - Lab Upgrade

    private var labUpgradeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.accent)
                Text("Lab Upgrades")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text("Lv. \(viewModel.currentBuilding.level)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            if viewModel.currentBuilding.level >= BuildingService.maxBuildingLevel {
                Text("Lab is at maximum level.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textTertiary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Next level unlocks more efficient research and higher throughput across the lab.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AppTheme.textSecondary)

                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Requirements")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(AppTheme.textTertiary)
                            Text(viewModel.labUpgradeRequirementLabel)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(String(format: "Cash: $%.0f", viewModel.labUpgradeCashCost))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                        Button {
                            viewModel.upgradeLab()
                        } label: {
                            Text("Upgrade Lab")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(
                                    LinearGradient(
                                        colors: [AppTheme.accent, AppTheme.accent.opacity(0.85)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isWorking || !viewModel.canUpgradeLab)
                    }
                }
            }
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    // MARK: - Lab Header

    private var labHeaderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.accent.opacity(0.3), AppTheme.accent.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    Image(systemName: "atom")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(AppTheme.accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Research & Development")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Level \(viewModel.currentBuilding.level) • Quality Enhancement Lab")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
            }

            HStack(spacing: 16) {
                researchPointsPill
                levelPill
            }
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
        )
    }

    private var researchPointsPill: some View {
        HStack(spacing: 8) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
            Text("\(viewModel.profile?.researchPoints ?? 0)")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.accent)
            Text("pts")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppTheme.surfaceAlt)
        .clipShape(Capsule())
    }

    private var levelPill: some View {
        HStack(spacing: 6) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
            Text("Lv. \(viewModel.currentBuilding.level)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppTheme.surfaceAlt.opacity(0.7))
        .clipShape(Capsule())
    }

    // MARK: - Cycle Control (Timer / Start / Collect)

    private var cycleControlSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.accent)
                Text("Research Cycle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
            }

            // Cost & expected output are always visible, regardless of cycle state.
            HStack(spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(AppTheme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cost")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.textTertiary)
                        Text(String(format: "$%.0f", viewModel.researchCycleCost))
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                }
                Rectangle()
                    .fill(AppTheme.border)
                    .frame(width: 1, height: 36)
                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 18))
                        .foregroundStyle(AppTheme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Output")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.textTertiary)
                        Text(viewModel.researchCycleOutputRangeText)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                }
                Spacer()
            }
            .padding(16)
            .background(AppTheme.surfaceAlt.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            if viewModel.isWorking {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(AppTheme.accent)
                    Text("Processing...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else if viewModel.isReadyToCollect {
                Button {
                    viewModel.collectResearch()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Results Ready")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("Collect research points")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        Spacer()
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.chipReady, AppTheme.chipReady.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            } else if viewModel.isCycleRunning {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .stroke(AppTheme.surfaceAlt, lineWidth: 6)
                                .frame(width: 72, height: 72)
                            Circle()
                                .trim(from: 0, to: viewModel.cycleProgress(now: context.date))
                                .stroke(AppTheme.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                .frame(width: 72, height: 72)
                                .rotationEffect(.degrees(-90))
                            Text(viewModel.timeRemaining(now: context.date) ?? "—")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppTheme.textPrimary)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Analysis in progress")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("\(viewModel.researchCycleOutputRangeText) when complete")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                        Spacer()
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(AppTheme.surfaceAlt.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            } else {
                Button {
                    viewModel.startResearchCycle()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 28))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Start Research Cycle")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("Spend $\(Int(viewModel.researchCycleCost)) to generate research points")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        Spacer()
                        Image(systemName: "flask.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.accent, AppTheme.accent.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Research Projects (by category)

    private var researchProjectsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.accent)
                Text("Research Projects")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
            }

            if viewModel.items.isEmpty {
                Text("No products to research. Items will appear when the economy is seeded.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textTertiary)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(viewModel.itemsByCategory, id: \.category.id) { group in
                    categorySection(category: group.category, items: group.items)
                }
            }
        }
    }

    private func categorySection(category: ItemCategory, items: [Item]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: categoryIcon(category))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.accent.opacity(0.9))
                Text(category.rawValue)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(items) { item in
                    researchProjectCard(item: item)
                }
            }
        }
    }

    private func researchProjectCard(item: Item) -> some View {
        let quality = viewModel.currentQuality(for: item)
        let level = quality?.qualityLevel ?? 1
        let progress = quality?.currentResearchPoints ?? 0
        let required = viewModel.requiredPoints(forLevel: level)
        let progressFraction = required > 0 ? min(1.0, Double(progress) / Double(required)) : 0

        return Button {
            applyPointsText = viewModel.pointsToApplyText
            selectedItem = item
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                resourceIconView(name: item.name)
                    .frame(width: 64, height: 64)
                    .aspectRatio(1, contentMode: .fit)

                HStack {
                    Text(item.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 4)
                    Text("Q\(level)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(AppTheme.accent.opacity(0.2))
                        .clipShape(Capsule())
                }

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(AppTheme.surfaceAlt)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(AppTheme.accent.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .scaleEffect(x: progressFraction, y: 1, anchor: .leading)
                        .frame(height: 6)
                }
                .frame(height: 6)
                .clipped()

                Text("\(progress)/\(required)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.surfaceAlt.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Apply Sheet

    private func applyPointsSheet(for item: Item) -> some View {
        let quality = viewModel.currentQuality(for: item)
        let level = quality?.qualityLevel ?? 1
        let progress = quality?.currentResearchPoints ?? 0
        let required = viewModel.requiredPoints(forLevel: level)
        let available = viewModel.profile?.researchPoints ?? 0

        return NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    HStack(spacing: 16) {
                        resourceIconView(name: item.name)
                            .frame(width: 96, height: 96)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Quality Q\(level) • \(progress)/\(required) to Q\(level + 1)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(20)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Points to apply")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.textTertiary)
                        TextField("Amount", text: $applyPointsText)
                            .keyboardType(.numberPad)
                            .font(.system(size: 17, weight: .medium, design: .monospaced))
                            .padding(16)
                            .background(AppTheme.surfaceAlt)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    Text("Available: \(available) research points")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)

                    Spacer()

                    Button {
                        let amount = Int(applyPointsText) ?? 0
                        viewModel.pointsToApplyText = applyPointsText
                        viewModel.applyResearchPoints(to: item, amount: amount)
                        selectedItem = nil
                    } label: {
                        HStack {
                            Image(systemName: "arrow.down.to.line")
                            Text("Apply Research Points")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isWorking || (Int(applyPointsText) ?? 0) <= 0 || (Int(applyPointsText) ?? 0) > available)
                }
                .padding(20)
            }
            .navigationTitle("Apply to \(item.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        selectedItem = nil
                    }
                    .foregroundStyle(AppTheme.accent)
                }
            }
        }
    }

    // MARK: - Helpers

    private func categoryIcon(_ cat: ItemCategory) -> String {
        switch cat {
        case .rawMaterial: return "cube.fill"
        case .refinedMaterial: return "sparkles"
        case .fuel: return "fuelpump.fill"
        case .component: return "gearshape.2.fill"
        case .luxuryGood: return "diamond.fill"
        case .buildingMaterial: return "building.2.fill"
        }
    }

    @ViewBuilder
    private func resourceIconView(name: String) -> some View {
        if let assetName = resourceAssetName(for: name) {
            Image(assetName)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
        } else {
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.accent.opacity(0.2))
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
        if key.contains("sand") { return "icon_sand" }
        if key.contains("stone") || key.contains("quarry") { return "icon_stone" }
        if key.contains("gravel") { return "icon_gravel" }
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
        if key.contains("brick") { return "icon_brick" }
        if key.contains("concrete mix") { return "icon_concrete_mix" }
        if key.contains("foundation") { return "icon_foundation" }
        if key.contains("window") { return "icon_window" }
        if key.contains("walls") { return "icon_brick_wall" }
        if key.contains("gold bar") { return "icon_gold_bar" }
        if key.contains("silver bar") { return "icon_silver_bar" }
        if key.contains("cut diamond") { return "icon_cut_diamond" }
        if key.contains("diamond dust") { return "icon_diamond_dust" }
        if key.contains("diamond drill bit") { return "icon_diamond_drill_bit" }
        if key.contains("precision cutting head") { return "icon_precision_cutting_head" }
        if key.contains("heat sink") || key.contains("heatsink") { return "icon_heat_sink" }
        if key.contains("microchip") { return "icon_microchip" }
        if key.contains("machine computer") { return "icon_machine_computer" }
        if key.contains("machine gear") { return "icon_machine_gear" }
        if key.contains("robotic machine arm") { return "icon_robotic_machine_arm" }
        if key.contains("gold ring") { return "icon_gold_ring" }
        if key.contains("silver ring") { return "icon_silver_ring" }
        if key.contains("gold watch") { return "icon_gold_watch" }
        if key.contains("silver watch") { return "icon_silver_watch" }
        if key.contains("luxury ring") { return "icon_luxury_ring" }
        if key.contains("luxury watch") { return "icon_luxury_watch" }
        return nil
    }
}

#Preview {
    NavigationStack {
        ResearchAndDevelopmentView(
            userID: "demo-user-id-12345",
            building: Building(
                id: "building-research-and-development",
                name: "Research & Development",
                type: .researchAndDevelopment,
                level: 1,
                capacity: 1,
                slotIndex: 0,
                resourceType: nil,
                abundance: nil,
                isStarterMine: false,
                isProducing: false,
                productionStartedAt: nil,
                productionEndsAt: nil,
                pendingOutputQuantity: nil,
                pendingOutputItemId: nil,
                pendingOutputItemName: nil,
                pendingOutputQuality: nil,
                isListedOnMarket: false,
                marketListingID: nil
            )
        )
    }
}
