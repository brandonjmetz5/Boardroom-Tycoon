import SwiftUI

struct ResourceMarketView: View {
    let userID: String

    @StateObject private var viewModel: MarketViewModel
    @State private var showFilterSheet = false
    @State private var priceMinText: String = ""
    @State private var priceMaxText: String = ""
    @State private var showOnlyCPUListings = false
    @State private var showOnlyPlayerListings = false
    @State private var showOnlyGoodDeals = false
    @State private var hideOverpriced = false

    init(userID: String) {
        self.userID = userID
        _viewModel = StateObject(wrappedValue: MarketViewModel(userID: userID))
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            resourceListingsContent
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Resource Market")
                    .font(AppTheme.titleMedium())
                    .foregroundStyle(AppTheme.textPrimary)
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: InventoryView(userID: userID)) {
                    Image(systemName: "building.2")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                }
            }
        }
        .onAppear {
            viewModel.loadResourceListings()
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

    // MARK: - Content

    private var resourceListingsContent: some View {
        let baseListings = viewModel.resourceListings
        let filteredListings = baseListings.filter { listing in
            // Local advanced filters on top of view model filters.
            if showOnlyCPUListings && listing.sellerUserID != "CPU" { return false }
            if showOnlyPlayerListings && listing.sellerUserID == "CPU" { return false }

            if let minPrice = Double(priceMinText.replacingOccurrences(of: ",", with: ".")),
               listing.pricePerUnit < minPrice {
                return false
            }
            if let maxPrice = Double(priceMaxText.replacingOccurrences(of: ",", with: ".")),
               listing.pricePerUnit > maxPrice {
                return false
            }

            let delta = viewModel.dealDeltaForListing(listing) ?? 0
            if showOnlyGoodDeals && delta > -10 { return false }
            if hideOverpriced && delta >= 15 { return false }

            return true
        }

        let totalCount = filteredListings.count
        let goodDealsCount = filteredListings.filter { (viewModel.dealDeltaForListing($0) ?? 0) <= -10 }.count
        let overheatedCount = filteredListings.filter { (viewModel.dealDeltaForListing($0) ?? 0) >= 15 }.count

        return VStack(spacing: 0) {
            // Hero stats header
            VStack(alignment: .leading, spacing: 12) {
                Text("Live resource market")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                HStack(spacing: 10) {
                    statPill(title: "Listings", value: "\(totalCount)")
                    statPill(title: "Good deals", value: "\(goodDealsCount)")
                    statPill(title: "Overpriced", value: "\(overheatedCount)")
                    Spacer()
                }
            }
            .padding(.horizontal, AppTheme.horizontalPadding)
            .padding(.top, 8)

            // Filters row
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Filters")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    HStack(spacing: 8) {
                        Menu {
                            Button("All resources") {
                                viewModel.filterResourceListingsID = nil
                            }
                            ForEach(MarketCatalog.tradeableItems(), id: \.id) { item in
                                Button(item.name) {
                                    viewModel.filterResourceListingsID = item.id
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(resourceFilterLabel)
                                    .lineLimit(1)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppTheme.cardBackgroundAlt)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        Menu {
                            Button("All quality") {
                                viewModel.minQualityForListings = 0
                            }
                            ForEach(1...5, id: \.self) { q in
                                Button("Q\(q)+") {
                                    viewModel.minQualityForListings = q
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(viewModel.minQualityForListings == 0 ? "All quality" : "Q\(viewModel.minQualityForListings)+")
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppTheme.cardBackgroundAlt)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Button {
                        showFilterSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                            Text("Advanced")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.cardBackgroundAlt)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    Text("Cheapest first")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }
            .padding(.horizontal, AppTheme.horizontalPadding)
            .padding(.vertical, 8)

            if let err = viewModel.buyListingErrorMessage {
                Text(err)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textError)
                    .padding(.horizontal, AppTheme.horizontalPadding)
                    .padding(.bottom, 8)
            }

            if viewModel.resourceListingsLoading {
                Spacer()
                ProgressView("Loading listings...")
                    .controlSize(.large)
                    .tint(.white)
                    .foregroundStyle(AppTheme.textPrimary)
            } else if let err = viewModel.resourceListingsErrorMessage {
                Spacer()
                Text(err)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(AppTheme.textError)
                    .padding()
            } else if filteredListings.isEmpty {
                Spacer()
                Text("No listings\(viewModel.filterResourceListingsID != nil || viewModel.minQualityForListings > 0 ? " matching filters" : ""). Try changing filters or list items from Inventory.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(filteredListings) { listing in
                            resourceListingRow(listing: listing)
                        }
                    }
                    .padding(.horizontal, AppTheme.horizontalPadding)
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            viewModel.loadAggregatesIfNeeded()
        }
    }

    private var resourceFilterLabel: String {
        guard let id = viewModel.filterResourceListingsID else { return "All resources" }
        return MarketCatalog.tradeableItems().first(where: { $0.id == id })?.name ?? id
    }

    private func resourceListingRow(listing: MarketListing) -> some View {
        let isMine = listing.sellerUserID == userID
        let qtyText = listing.item.isFractional ? String(format: "%.2f", listing.quantity) : String(Int(listing.quantity))
        let delta = viewModel.dealDeltaForListing(listing)
        return HStack(alignment: .center, spacing: 12) {
            resourceIconView(name: listing.item.name)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(listing.item.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Q\(listing.quality)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(AppTheme.cardBackgroundAlt)
                        .clipShape(Capsule())
                    if let delta {
                        let text = String(format: "%+.0f%%", delta)
                        Text(text)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(delta <= 0 ? AppTheme.chipPositive : AppTheme.textError)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                (delta <= 0 ? AppTheme.chipPositive : AppTheme.textError)
                                    .opacity(0.15)
                            )
                            .clipShape(Capsule())
                    }
                }
                Text("\(qtyText) available · \(String(format: "$%.2f", listing.pricePerUnit))/unit")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            Spacer()
            if isMine {
                Button("Cancel listing") {
                    viewModel.cancelMyListing(listing)
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.textError)
                .disabled(viewModel.isSubmitting)
            } else {
                Button("Buy") {
                    viewModel.openBuyListingSheet(listing)
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(AppTheme.chipReady)
                .clipShape(Capsule())
            }
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    private func statPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.textTertiary)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppTheme.cardBackgroundAlt)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Filter sheet

    private var filterSheet: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Filter listings")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Price range (per unit)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                            HStack(spacing: 12) {
                                TextField("Min", text: $priceMinText)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                                TextField("Max", text: $priceMaxText)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Seller type")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                            Toggle("Only CPU liquidity", isOn: $showOnlyCPUListings)
                                .tint(AppTheme.accent)
                            Toggle("Only player listings", isOn: $showOnlyPlayerListings)
                                .tint(AppTheme.accent)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Deal quality")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                            Toggle("Show only good deals (≤ -10% vs market)", isOn: $showOnlyGoodDeals)
                                .tint(AppTheme.accent)
                            Toggle("Hide overpriced listings (≥ +15% vs market)", isOn: $hideOverpriced)
                                .tint(AppTheme.accent)
                        }
                    }
                    .padding(AppTheme.cardPadding)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.cardBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") {
                        priceMinText = ""
                        priceMaxText = ""
                        showOnlyCPUListings = false
                        showOnlyPlayerListings = false
                        showOnlyGoodDeals = false
                        hideOverpriced = false
                    }
                    .foregroundStyle(AppTheme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showFilterSheet = false
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.chipReady)
                }
            }
        }
    }

    // MARK: - Resource icons

    @ViewBuilder
    private func resourceIconView(name: String) -> some View {
        if let assetName = resourceAssetName(for: name) {
            ZStack {
                Circle()
                    .fill(AppTheme.cardBackgroundAlt.opacity(0.95))
                    .frame(width: 40, height: 40)
                Image(assetName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(width: 38, height: 38)
                    .clipShape(Circle())
            }
        } else {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.22))
                    .frame(width: 40, height: 40)
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
}

