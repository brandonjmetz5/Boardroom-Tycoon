import SwiftUI

struct ResourceMarketView: View {
    let userID: String

    @StateObject private var viewModel: MarketViewModel

    // Single entry point into a full filter suite.
    @State private var showFilterSheet = false

    // Local filter UI state that feeds into the view model.
    @State private var selectedResourceID: String?
    @State private var selectedQuality: Int?
    @State private var priceMinText: String = ""
    @State private var priceMaxText: String = ""

    init(userID: String) {
        self.userID = userID
        _viewModel = StateObject(wrappedValue: MarketViewModel(userID: userID))
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

            content
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Resource Exchange")
                    .font(AppTheme.titleMedium())
                    .foregroundStyle(AppTheme.textPrimary)
            }
        }
        .onAppear {
            viewModel.loadResourceListings()
            viewModel.loadAggregatesIfNeeded()
            syncFilterStateFromViewModel()
        }
        .sheet(isPresented: $showFilterSheet) {
            filterSheet
        }
        .alert("Buy this listing?", isPresented: Binding(
            get: { viewModel.selectedListingToBuy != nil },
            set: { if !$0 { viewModel.closeBuyListingSheet() } }
        )) {
            Button("Cancel", role: .cancel) { viewModel.closeBuyListingSheet() }
            Button("Buy") { viewModel.confirmBuyFromListing() }
        } message: {
            if let listing = viewModel.selectedListingToBuy {
                let qtyText = listing.item.isFractional ? String(format: "%.2f", listing.quantity) : String(Int(listing.quantity))
                let total = listing.quantity * listing.pricePerUnit
                Text("\(listing.item.name) (Q\(listing.quality))\nQuantity: \(qtyText)\nTotal: \(String(format: "$%.2f", total)) (3% fee applied)")
            }
        }
    }

    // MARK: - Main content

    private var content: some View {
        let base = viewModel.resourceListings
        let filtered = base.filter { listing in
            if let selectedResourceID, listing.item.id != selectedResourceID { return false }
            if let selectedQuality, listing.quality != selectedQuality { return false }

            if let minPrice = parsePrice(priceMinText), listing.pricePerUnit < minPrice {
                return false
            }
            if let maxPrice = parsePrice(priceMaxText), listing.pricePerUnit > maxPrice {
                return false
            }

            return true
        }

        // Precompute deal deltas once per render pass to avoid repeated heavy work
        let listingsWithDelta: [(listing: MarketListing, delta: Double?)] = filtered.map { listing in
            (listing, viewModel.dealDeltaForListing(listing))
        }

        let sorted: [MarketListing] = listingsWithDelta
            .map { $0.listing }
            .sorted { $0.pricePerUnit < $1.pricePerUnit }

        let goodDealsCount = listingsWithDelta.filter { ($0.delta ?? 0) <= -10 }.count
        let overheatedCount = listingsWithDelta.filter { ($0.delta ?? 0) >= 15 }.count

        return VStack(spacing: 0) {
            headerSection(
                total: filtered.count,
                good: goodDealsCount,
                overheated: overheatedCount
            )

            if let err = viewModel.buyListingErrorMessage {
                Text(err)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textError)
                    .padding(.horizontal, AppTheme.horizontalPadding)
                    .padding(.bottom, 6)
            }

            if viewModel.resourceListingsLoading {
                Spacer()
                ProgressView("Scanning live offers…")
                    .controlSize(.large)
                    .tint(.white)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
            } else if let err = viewModel.resourceListingsErrorMessage {
                Spacer()
                Text(err)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(AppTheme.textError)
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            } else if sorted.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Text("No listings match your filters.")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Try loosening filters or list items from your inventory to seed the market.")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, AppTheme.horizontalPadding)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(sorted) { listing in
                            resourceListingCard(listing: listing)
                        }
                    }
                    .padding(.horizontal, AppTheme.horizontalPadding)
                    .padding(.vertical, 10)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header

    private func headerSection(total: Int, good: Int, overheated: Int) -> some View {
        VStack(spacing: 10) {
            marketRail(title: "Desk Status", systemImage: "dot.radiowaves.left.and.right", tone: .priority) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 34, height: 34)
                            .background(AppTheme.accent.opacity(0.16))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Live order board")
                                .font(AppTheme.bodyMedium())
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Scan listings, compare deal delta, and execute fast.")
                                .font(AppTheme.caption())
                                .foregroundStyle(AppTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                    }

                    HStack(spacing: 8) {
                        statPill(title: "LISTINGS", value: "\(total)")
                        statPill(title: "BELOW AVG", value: "\(good)")
                        statPill(title: "OVERHEATED", value: "\(overheated)")
                        Spacer()
                    }
                }
            }

            marketRail(title: "Execution Controls", systemImage: "slider.horizontal.3") {
                HStack(spacing: 10) {
                    Button {
                        syncFilterStateFromViewModel()
                        showFilterSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            Text("Filters")
                            if hasActiveFiltersSummary {
                                Text(filtersSummaryText)
                                    .font(.system(size: 11, weight: .medium))
                                    .lineLimit(1)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(AppTheme.surface.opacity(0.58))
                                    .clipShape(Capsule())
                            }
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppTheme.surfaceAlt.opacity(0.58))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border.opacity(0.95), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    Spacer()
                    Text("Cheapest first")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(AppTheme.surfaceAlt.opacity(0.58))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border.opacity(0.95), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .padding(.horizontal, AppTheme.horizontalPadding)
        .padding(.top, 8)
    }

    private var hasActiveFiltersSummary: Bool {
        if selectedResourceID != nil { return true }
        if selectedQuality != nil { return true }
        if !priceMinText.isEmpty || !priceMaxText.isEmpty { return true }
        return false
    }

    private var filtersSummaryText: String {
        var parts: [String] = []
        if let id = selectedResourceID,
           let item = MarketCatalog.tradeableItems().first(where: { $0.id == id }) {
            parts.append(item.name)
        }
        if let selectedQuality {
            parts.append("Q\(selectedQuality)")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Listing cards

    private func resourceListingCard(listing: MarketListing) -> some View {
        let isMyListing = listing.sellerUserID == userID
        let qtyText = listing.item.isFractional ? String(format: "%.2f", listing.quantity) : String(Int(listing.quantity))
        let delta = viewModel.dealDeltaForListing(listing)
        let total = listing.quantity * listing.pricePerUnit

        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppTheme.surface.opacity(0.82))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppTheme.border.opacity(0.95), lineWidth: 1)
                )

            // Slim accent bar on the left to show deal quality without heavy gradients.
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(
                    (delta ?? 0) <= -10
                    ? AppTheme.chipPositive
                    : (delta ?? 0) >= 15
                      ? AppTheme.textError
                      : AppTheme.surfaceAlt
                )
                .frame(width: 6)
                .padding(.vertical, 10)
                .padding(.leading, 3)

            HStack(alignment: .center, spacing: 12) {
                resourceIconView(name: listing.item.name)
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(listing.item.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(1)

                        Text("Q\(listing.quality)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.surfaceAlt.opacity(0.58))
                            .clipShape(Capsule())

                        if let delta {
                            dealChip(delta: delta)
                        }
                    }

                    Text("\(qtyText) available · \(String(format: "$%.2f", listing.pricePerUnit))/unit")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AppTheme.textTertiary)

                    HStack(spacing: 6) {
                        Text("Market listing")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                        Spacer()

                        Text("Total \(String(format: "$%.2f", total))")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    // Keep only the chip here; bar was visually nice but heavy. The hero stats + chip give enough signal.
                }

                Spacer(minLength: 6)

                VStack(alignment: .trailing, spacing: 6) {
                    if isMyListing {
                        Button {
                            viewModel.cancelMyListing(listing)
                        } label: {
                            Text("Cancel")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.textError)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(AppTheme.surfaceAlt.opacity(0.58))
                                .clipShape(Capsule())
                        }
                        .disabled(viewModel.isSubmitting)

                        Text("Your listing")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AppTheme.textTertiary)
                    } else {
                        Button {
                            viewModel.openBuyListingSheet(listing)
                        } label: {
                            HStack(spacing: 7) {
                                if viewModel.buyListingInProgress && viewModel.selectedListingToBuy?.id == listing.id {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "cart.fill.badge.plus")
                                }
                                Text("Buy")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(AppTheme.chipReady)
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        }
                        .disabled(viewModel.buyListingInProgress)
                    }
                }
            }
            .padding(AppTheme.cardPadding)
        }
    }

    private func statPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.textTertiary)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppTheme.surfaceAlt.opacity(0.58))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border.opacity(0.95), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func dealChip(delta: Double) -> some View {
        let text = String(format: "%+.0f%%", delta)
        let isValue = delta <= 0
        let color = isValue ? AppTheme.chipPositive : AppTheme.textError

        return Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.18))
            .clipShape(Capsule())
    }

    private func dealBar(delta: Double) -> some View {
        let clamped = max(-40, min(40, delta))
        let normalized = (clamped + 40) / 80

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(delta <= 0 ? "Below market" : "Above market")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppTheme.textTertiary)
                Spacer()
                Text(String(format: "%+.0f%%", delta))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(delta <= 0 ? AppTheme.chipPositive : AppTheme.textError)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.cardBackgroundAlt.opacity(0.9))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.chipPositive, AppTheme.textError],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(4, geo.size.width * normalized))
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Filter sheet (single entry)

    private var filterSheet: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Tune the order book")
                            .font(AppTheme.titleSmall())
                            .foregroundStyle(AppTheme.textPrimary)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Resource")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.textSecondary)

                            let items = MarketCatalog.tradeableItems()
                            LazyVGrid(
                                columns: [
                                    GridItem(.adaptive(minimum: 90), spacing: 10)
                                ],
                                spacing: 10
                            ) {
                                iconFilterChip(
                                    title: "All",
                                    iconName: nil,
                                    isSelected: selectedResourceID == nil
                                ) {
                                    selectedResourceID = nil
                                }

                                ForEach(items, id: \.id) { item in
                                    iconFilterChip(
                                        title: item.name,
                                        iconName: item.name,
                                        isSelected: selectedResourceID == item.id
                                    ) {
                                        selectedResourceID = item.id
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Quality")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.textSecondary)

                            HStack(spacing: 8) {
                                filterChip(title: "All", isSelected: selectedQuality == nil) {
                                    selectedQuality = nil
                                }
                                ForEach(1...5, id: \.self) { q in
                                    filterChip(title: "Q\(q)", isSelected: selectedQuality == q) {
                                        selectedQuality = q
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Price per unit")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                            HStack(spacing: 12) {
                                TextField("Min", text: $priceMinText)
                                    .keyboardType(.decimalPad)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 12)
                                    .background(AppTheme.surfaceAlt.opacity(0.58))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border, lineWidth: 1))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                TextField("Max", text: $priceMaxText)
                                    .keyboardType(.decimalPad)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 12)
                                    .background(AppTheme.surfaceAlt.opacity(0.58))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border, lineWidth: 1))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }

                    }
                    .padding(.horizontal, AppTheme.horizontalPadding)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.cardBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") {
                        resetFilters()
                    }
                    .foregroundStyle(AppTheme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") {
                        applyFiltersToViewModel()
                        showFilterSheet = false
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.chipReady)
                }
            }
        }
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSelected ? .black : AppTheme.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    isSelected
                    ? AppTheme.accent
                    : AppTheme.surfaceAlt.opacity(0.58)
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? AppTheme.accent.opacity(0.2) : AppTheme.border.opacity(0.95), lineWidth: 1)
                )
                .clipShape(Capsule())
        }
    }

    private func iconFilterChip(title: String, iconName: String?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                if let iconName {
                    resourceIconView(name: iconName)
                        .frame(width: 28, height: 28)
                } else {
                    ZStack {
                        Circle().fill(AppTheme.surfaceAlt.opacity(0.58))
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .frame(width: 28, height: 28)
                }
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(AppTheme.surfaceAlt.opacity(0.58))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? AppTheme.accent.opacity(0.7) : AppTheme.border.opacity(0.95), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Resource icons

    @ViewBuilder
    private func resourceIconView(name: String) -> some View {
        if let assetName = resourceAssetName(for: name) {
            ZStack {
                Circle()
                    .fill(AppTheme.cardBackgroundAlt.opacity(0.95))
                Image(assetName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .clipShape(Circle())
            }
        } else {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.22))
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: 14, weight: .bold))
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

    // MARK: - Helpers

    private func parsePrice(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    private func resetFilters() {
        selectedResourceID = nil
        selectedQuality = nil
        priceMinText = ""
        priceMaxText = ""
    }

    private func syncFilterStateFromViewModel() {
        selectedResourceID = viewModel.filterResourceListingsID
        selectedQuality = viewModel.minQualityForListings > 0 ? viewModel.minQualityForListings : nil
    }

    private func applyFiltersToViewModel() {
        viewModel.filterResourceListingsID = selectedResourceID
        viewModel.minQualityForListings = 0
    }

    private func marketRail<Content: View>(
        title: String,
        systemImage: String,
        tone: MarketRailTone = .normal,
        @ViewBuilder content: () -> Content
    ) -> some View {
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
            content()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.surface.opacity(0.82)))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(tone == .priority ? AppTheme.accent.opacity(0.32) : AppTheme.border.opacity(0.95), lineWidth: 1)
        )
    }
}

private enum MarketRailTone {
    case normal
    case priority
}

