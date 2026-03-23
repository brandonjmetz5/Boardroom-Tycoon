//
//  InventoryView.swift
//  Boardroom Tycoon
//
//  Unified inventory command console.
//

import SwiftUI

/// Resource PNGs often include transparent padding; we draw larger than the visible slot and clip
/// so the artwork reads clearly without squinting.
private enum InventoryResourceIconMetrics {
    /// Collapsed resource row (main list).
    static let rowSlot: CGFloat = 54
    /// Expanded quality sub-rows.
    static let qualitySlot: CGFloat = 44
    /// List-on-market sheet header.
    static let sheetSlot: CGFloat = 64
    /// Drawable scale before clipping (higher = more “zoom” into padded sprites).
    static let assetZoom: CGFloat = 1.62
}

struct InventoryView: View {
    let userID: String

    @StateObject private var viewModel: InventoryViewModel
    @State private var expandedResourceIDs: Set<String> = []

    init(userID: String) {
        self.userID = userID
        _viewModel = StateObject(wrappedValue: InventoryViewModel(userID: userID))
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            LinearGradient(
                colors: [AppTheme.surface.opacity(0.12), Color.clear, AppTheme.surface.opacity(0.10)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Group {
                if viewModel.isLoading {
                    VStack(spacing: 14) {
                        ProgressView().scaleEffect(1.15).tint(AppTheme.accent)
                        Text("Loading inventory network...")
                            .font(AppTheme.caption())
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                } else if let errorMessage = viewModel.errorMessage {
                    InventoryRail(title: "System Fault", systemImage: "exclamationmark.triangle.fill", tone: .priority) {
                        Text(errorMessage)
                            .font(AppTheme.caption())
                            .foregroundStyle(AppTheme.textError)
                    }
                    .padding(.horizontal, AppTheme.horizontalPadding)
                } else if viewModel.inventoryItems.isEmpty {
                    InventoryRail(title: "Inventory", systemImage: "shippingbox.fill") {
                        Text("No items detected. Produce or acquire resources to populate your warehouse.")
                            .font(AppTheme.caption())
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(.horizontal, AppTheme.horizontalPadding)
                } else {
                    ScrollView {
                        let sections = viewModel.resourceGroupsByCategory
                        VStack(alignment: .leading, spacing: 10) {
                            commandHeader
                            insightStatsSection
                            ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                                categorySection(category: section.category, resources: section.resources)
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
                Text("Inventory")
                    .font(AppTheme.titleMedium())
                    .foregroundStyle(AppTheme.textPrimary)
            }
        }
        .onAppear { viewModel.loadInventory() }
        .sheet(item: $viewModel.selectedItemForListing) { item in
            listOnMarketSheet(item: item)
        }
    }

    private var commandHeader: some View {
        InventoryRail(title: "Warehouse Command", systemImage: "shippingbox.fill", tone: .priority) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Inventory Operations Console")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Quality-tiered stock intelligence and liquidation controls.")
                        .font(AppTheme.caption())
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                Text("LIVE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.chipReady)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.chipReady.opacity(0.16)))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.chipReady.opacity(0.45), lineWidth: 1))
            }
        }
    }

    private var insightStatsSection: some View {
        InventoryRail(title: "Inventory Insights", systemImage: "chart.bar.xaxis") {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    StatBlock(title: "Total Value", value: String(format: "$%.2f", viewModel.totalInventoryValue), accent: AppTheme.accent)
                    StatBlock(title: "Total Qty", value: viewModel.formattedTotalQuantity(), accent: AppTheme.chipReady)
                }
                HStack(spacing: 10) {
                    StatBlock(title: "Resource Types", value: "\(viewModel.distinctResourceCount)", accent: AppTheme.chipAvailable)
                    StatBlock(title: "Qual. Stacks", value: "\(viewModel.totalQualityStacks)", accent: AppTheme.chipListed)
                    StatBlock(title: "Highest Q", value: "Q\(viewModel.highestQualityAvailable)", accent: AppTheme.chipProducing)
                }
            }
        }
    }

    private func categorySection(category: ItemCategory, resources: [InventoryViewModel.ResourceGroup]) -> some View {
        InventoryRail(title: category.rawValue, systemImage: categoryIcon(for: category)) {
            VStack(spacing: 10) {
                ForEach(resources) { resource in
                    resourceExpandableCard(resource: resource)
                }
            }
        }
    }

    private func categoryIcon(for category: ItemCategory) -> String {
        switch category {
        case .rawMaterial: return "leaf.fill"
        case .refinedMaterial: return "sparkles"
        case .fuel: return "flame.fill"
        case .component: return "gearshape.fill"
        case .luxuryGood: return "diamond.fill"
        case .buildingMaterial: return "building.2.fill"
        }
    }

    private func resourceExpandableCard(resource: InventoryViewModel.ResourceGroup) -> some View {
        let isExpanded = expandedResourceIDs.contains(resource.id)
        let totalText = viewModel.formattedTotalQuantity(value: resource.totalQuantity, isFractional: resource.item.isFractional)

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                if isExpanded { expandedResourceIDs.remove(resource.id) } else { expandedResourceIDs.insert(resource.id) }
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    resourceIconView(name: resource.item.name, size: InventoryResourceIconMetrics.rowSlot)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(resource.item.name)
                            .font(AppTheme.bodyMedium())
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Total \(totalText)")
                            .font(AppTheme.caption())
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    Spacer()
                    Text("\(resource.qualities.count) Q")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.textTertiary)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(11)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().overlay(AppTheme.border)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(resource.qualities) { q in
                        qualityRow(resource: resource, quality: q)
                    }
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 10)
            }
        }
        .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.surfaceAlt.opacity(0.58)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border.opacity(0.95), lineWidth: 1))
    }

    private func qualityRow(resource: InventoryViewModel.ResourceGroup, quality: InventoryViewModel.QualityGroup) -> some View {
        let synthetic = InventoryItem(
            id: "\(resource.baseID)-q\(quality.quality)",
            item: resource.item,
            quantity: quality.quantity,
            quality: quality.quality
        )
        let value = ItemValueCatalog.value(quantity: quality.quantity, itemId: resource.item.id)

        return HStack(alignment: .center, spacing: 10) {
            resourceIconView(name: resource.item.name, size: InventoryResourceIconMetrics.qualitySlot)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("Q\(quality.quality)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(AppTheme.border.opacity(0.4)))
                    if let value {
                        Text(String(format: "$%.0f", value))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppTheme.accent)
                    }
                }
                Text("Qty: \(viewModel.formattedQuantity(for: synthetic))")
                    .font(AppTheme.caption())
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            Button {
                viewModel.openListSheet(for: synthetic)
            } label: {
                Text("List")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.accent)
                    .clipShape(Capsule())
            }
            .disabled(quality.quantity <= 0)
            .opacity(quality.quantity <= 0 ? 0.6 : 1)
        }
    }

    private func listOnMarketSheet(item: InventoryItem) -> some View {
        let (_, quality) = viewModel.resourceBaseIDAndQuality(for: item)
        return NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 12) {
                    InventoryRail(title: "List on Market", systemImage: "tag.fill", tone: .priority) {
                        VStack(alignment: .leading, spacing: 10) {
                            if let err = viewModel.listErrorMessage {
                                Text(err)
                                    .font(AppTheme.caption())
                                    .foregroundStyle(AppTheme.textError)
                            }
                            HStack(alignment: .center, spacing: 12) {
                                resourceIconView(name: item.item.name, size: InventoryResourceIconMetrics.sheetSlot)
                                Text(item.item.name)
                                    .font(AppTheme.titleSmall())
                                    .foregroundStyle(AppTheme.textPrimary)
                            }
                            Text("Q\(quality) · You have \(viewModel.formattedQuantity(for: item))")
                                .font(AppTheme.caption())
                                .foregroundStyle(AppTheme.textSecondary)

                            Text("Quantity to list")
                                .font(AppTheme.captionMedium())
                                .foregroundStyle(AppTheme.textSecondary)
                            TextField("Quantity", text: $viewModel.listQuantityText)
                                .keyboardType(item.item.isFractional ? .decimalPad : .numberPad)
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.surfaceAlt.opacity(0.58)))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border.opacity(0.95), lineWidth: 1))

                            Text("Price per unit ($)")
                                .font(AppTheme.captionMedium())
                                .foregroundStyle(AppTheme.textSecondary)
                            TextField("Price per unit", text: $viewModel.listPricePerUnitText)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.surfaceAlt.opacity(0.58)))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border.opacity(0.95), lineWidth: 1))
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, AppTheme.horizontalPadding)
                .padding(.top, 12)
            }
            .navigationTitle("List on Market")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { viewModel.closeListSheet() }
                        .foregroundStyle(AppTheme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Post") { viewModel.postListing() }
                        .fontWeight(.bold)
                        .foregroundStyle(AppTheme.chipReady)
                        .disabled(viewModel.isPostingListing)
                }
            }
            .overlay {
                if viewModel.isPostingListing {
                    ProgressView("Posting...")
                        .padding(20)
                        .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border, lineWidth: 1))
                }
            }
        }
    }

    @ViewBuilder
    private func resourceIconView(name: String, size: CGFloat, assetZoom: CGFloat = InventoryResourceIconMetrics.assetZoom) -> some View {
        if let assetName = resourceAssetName(for: name) {
            ZStack {
                Circle()
                    .fill(AppTheme.surfaceAlt.opacity(0.95))
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .stroke(AppTheme.border.opacity(0.85), lineWidth: 1)
                    )
                Image(assetName)
                    .renderingMode(.original)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: size * assetZoom, height: size * assetZoom)
                    .frame(width: size, height: size)
                    .clipped()
                    .clipShape(Circle())
            }
            .accessibilityHidden(true)
        } else {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.25))
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .stroke(AppTheme.border.opacity(0.6), lineWidth: 1)
                    )
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: max(12, size * 0.38), weight: .bold))
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
        if key.contains("sand quarry") || key == "sand" || key.contains("raw sand") { return "icon_sand" }
        if key.contains("stone quarry") || key == "stone" || key.contains("quarry") || key.contains("raw stone") { return "icon_stone" }
        if key.contains("gravel quarry") || key == "gravel" || key.contains("raw gravel") { return "icon_gravel" }
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
}

private enum InventoryRailTone {
    case normal
    case priority
}

private struct InventoryRail<Content: View>: View {
    let title: String
    let systemImage: String
    var tone: InventoryRailTone
    private let content: Content

    init(
        title: String,
        systemImage: String,
        tone: InventoryRailTone = .normal,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tone = tone
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
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
        .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.surface.opacity(0.82)))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(tone == .priority ? AppTheme.accent.opacity(0.32) : AppTheme.border.opacity(0.95), lineWidth: 1)
        )
    }
}

private struct StatBlock: View {
    let title: String
    let value: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.textTertiary)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(accent)
                .lineLimit(1)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.surfaceAlt.opacity(0.58)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border.opacity(0.95), lineWidth: 1))
    }
}

#Preview {
    NavigationStack {
        InventoryView(userID: "demo-user-id-12345")
    }
}
