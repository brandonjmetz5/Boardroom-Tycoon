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

            VStack(spacing: 0) {
                Picker("Market", selection: $viewModel.marketSegment) {
                    Text("Auctions").tag(0)
                    Text("Buy Orders").tag(1)
                    Text("Resources").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, AppTheme.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 4)

                if viewModel.marketSegment == 0 {
                    auctionsContent
                } else if viewModel.marketSegment == 1 {
                    buyOrdersContent
                } else {
                    resourceListingsContent
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Market")
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
            viewModel.loadListings()
        }
        .onChange(of: viewModel.marketSegment) { _, newValue in
            if newValue == 1 { viewModel.loadBuyOrders() }
            if newValue == 2 { viewModel.loadResourceListings() }
        }
        .sheet(item: $viewModel.selectedListingForBid) { listing in
            bidSheetView(listing: listing)
        }
        .sheet(isPresented: $viewModel.showNewBuyOrderSheet) {
            newBuyOrderSheet
        }
        .sheet(item: $viewModel.selectedListingToBuy) { listing in
            buyListingSheet(listing: listing)
        }
        .alert("Fulfill Buy Order?", isPresented: Binding(
            get: { viewModel.selectedOrderForFulfillConfirm != nil },
            set: { if !$0 { viewModel.closeFulfillConfirm() } }
        )) {
            if let order = viewModel.selectedOrderForFulfillConfirm {
                Button("Cancel", role: .cancel) { viewModel.closeFulfillConfirm() }
                Button("Fulfill") { viewModel.fulfillBuyOrder(order) }
            }
        } message: {
            if let order = viewModel.selectedOrderForFulfillConfirm {
                Text("Deliver \(order.lines.map { "\(Int($0.quantity)) \($0.resourceName) (Q\($0.resourceQuality))" }.joined(separator: ", ")) and receive \(String(format: "$%.2f", order.netToSeller)) (3% fee applied).")
            }
        }
    }

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

    private var buyOrdersContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Menu {
                    Button("All categories") { viewModel.filterCategory = nil; viewModel.loadBuyOrders() }
                    ForEach(ItemCategory.allCases, id: \.self) { cat in
                        Button(cat.rawValue) {
                            viewModel.filterCategory = cat.rawValue
                            viewModel.loadBuyOrders()
                        }
                    }
                } label: {
                    Text(viewModel.filterCategory ?? "Category")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.cardBackgroundAlt)
                        .clipShape(Capsule())
                }
                Menu {
                    Button("All quality") { viewModel.filterQuality = nil; viewModel.loadBuyOrders() }
                    ForEach(1...5, id: \.self) { q in
                        Button("Q\(q)") {
                            viewModel.filterQuality = q
                            viewModel.loadBuyOrders()
                        }
                    }
                } label: {
                    Text(viewModel.filterQuality.map { "Q\($0)" } ?? "Quality")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.cardBackgroundAlt)
                        .clipShape(Capsule())
                }
                Spacer()
                Button("New Buy Order") {
                    viewModel.showNewBuyOrderSheet = true
                    viewModel.newOrderErrorMessage = nil
                    viewModel.newOrderLines = [NewOrderLine()]
                    viewModel.newOrderTotalPriceText = ""
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(AppTheme.chipReady)
                .clipShape(Capsule())
            }
            .padding(.horizontal, AppTheme.horizontalPadding)
            .padding(.vertical, 8)

            if let msg = viewModel.buyOrderActionMessage {
                Text(msg)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(msg.contains("received") ? AppTheme.chipPositive : AppTheme.textError)
                    .padding(.horizontal, AppTheme.horizontalPadding)
            }

            if viewModel.buyOrdersLoading {
                Spacer()
                ProgressView("Loading buy orders...")
                    .controlSize(.large)
                    .tint(.white)
                    .foregroundStyle(AppTheme.textPrimary)
            } else if let err = viewModel.buyOrdersErrorMessage {
                Spacer()
                Text(err)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(AppTheme.textError)
                    .padding()
            } else if viewModel.buyOrders.isEmpty {
                Spacer()
                VStack(alignment: .leading, spacing: 12) {
                    Text("No Buy Orders")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("No open buy orders match your filters. Post one with New Buy Order.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(AppTheme.cardPadding)
                .themedCard()
                .padding(.horizontal, AppTheme.horizontalPadding)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.buyOrders) { order in
                            buyOrderCard(order: order)
                        }
                    }
                    .padding(.horizontal, AppTheme.horizontalPadding)
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func buyOrderCard(order: BuyOrder) -> some View {
        let canFulfill = viewModel.canFulfill(order)
        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(order.lines) { line in
                    HStack(alignment: .center, spacing: 8) {
                        Text(line.resourceName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Q\(line.resourceQuality)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(AppTheme.cardBackgroundAlt)
                            .clipShape(Capsule())
                        Text("× \(Int(line.quantity))")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(format: "$%.2f", order.totalPrice))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(String(format: "$%.2f/unit", order.pricePerUnit))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("You receive: \(String(format: "$%.2f", order.netToSeller))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("3% fee")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }
            if order.buyerUserID == userID {
                Button("Cancel order") {
                    viewModel.cancelBuyOrder(order)
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.textError)
                .disabled(viewModel.isSubmitting)
            } else {
                if canFulfill {
                    Button("Fulfill Order") {
                        viewModel.confirmFulfillTapped(order)
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(AppTheme.chipReady)
                    .clipShape(Capsule())
                    .disabled(viewModel.isSubmitting)
                } else {
                    Text("Insufficient inventory for one or more resources.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AppTheme.textTertiary)
                    Button("Fulfill Order") { }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textMuted)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(AppTheme.cardBackgroundAlt)
                        .clipShape(Capsule())
                        .disabled(true)
                }
            }
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    // MARK: - Resource Listings (buy individual resources)

    private var resourceListingsContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
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
                    Text(resourceFilterLabel)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
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
                    Text(viewModel.minQualityForListings == 0 ? "All quality" : "Q\(viewModel.minQualityForListings)+")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(AppTheme.cardBackgroundAlt)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Spacer()
                Text("Cheapest first")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .padding(.horizontal, AppTheme.horizontalPadding)
            .padding(.vertical, 8)

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
            } else if viewModel.resourceListings.isEmpty {
                Spacer()
                Text("No listings\(viewModel.filterResourceListingsID != nil || viewModel.minQualityForListings > 0 ? " matching filters" : ""). Try changing filters or list items from Inventory.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(viewModel.resourceListings) { listing in
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
    }

    private var resourceFilterLabel: String {
        guard let id = viewModel.filterResourceListingsID else { return "All resources" }
        return MarketCatalog.tradeableItems().first(where: { $0.id == id })?.name ?? id
    }

    private func resourceListingRow(listing: MarketListing) -> some View {
        let isMine = listing.sellerUserID == userID
        let qtyText = listing.item.isFractional ? String(format: "%.2f", listing.quantity) : String(Int(listing.quantity))
        return HStack(alignment: .center, spacing: 12) {
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

    private func buyListingSheet(listing: MarketListing) -> some View {
        let maxQty = listing.quantity
        let qty = Double(viewModel.buyQuantityText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let total = qty * listing.pricePerUnit
        return NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    if let err = viewModel.buyListingErrorMessage {
                        Text(err)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.textError)
                    }
                    Text(listing.item.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Q\(listing.quality) · \(String(format: "$%.2f", listing.pricePerUnit))/unit")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("Quantity to buy (max \(listing.item.isFractional ? String(format: "%.2f", maxQty) : String(Int(maxQty))))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    TextField("Quantity", text: $viewModel.buyQuantityText)
                        .keyboardType(listing.item.isFractional ? .decimalPad : .numberPad)
                        .textFieldStyle(.roundedBorder)
                    if total > 0 {
                        Text("Total: \(String(format: "$%.2f", total)) (3% fee at checkout)")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                }
                .padding(AppTheme.cardPadding)
            }
            .navigationTitle("Buy \(listing.item.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.cardBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        viewModel.closeBuyListingSheet()
                    }
                    .foregroundStyle(AppTheme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Confirm") {
                        viewModel.confirmBuyFromListing()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.chipReady)
                    .disabled(viewModel.buyListingInProgress)
                }
            }
            .overlay {
                if viewModel.buyListingInProgress {
                    ProgressView("Buying...")
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                }
            }
        }
    }

    private var newBuyOrderSheet: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let err = viewModel.newOrderErrorMessage {
                            Text(err)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AppTheme.textError)
                        }
                        Text("Resources (add as many as you need)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                        ForEach(viewModel.newOrderLines.indices, id: \.self) { index in
                            newOrderLineRow(index: index)
                        }
                        Button("Add resource") {
                            viewModel.addNewOrderLine()
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.chipReady)
                        .padding(.vertical, 8)
                        Group {
                            Text("Total price (you pay)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                            TextField("Total price", text: $viewModel.newOrderTotalPriceText)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                        }
                        if let total = Double(viewModel.newOrderTotalPriceText), total > 0 {
                            let fee = viewModel.feeAmount(for: total)
                            let net = viewModel.netToSeller(for: total)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Market fee (3%): \(String(format: "$%.2f", fee))")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(AppTheme.textTertiary)
                                Text("Seller receives: \(String(format: "$%.2f", net))")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                        if let cash = viewModel.profile?.cash, let total = Double(viewModel.newOrderTotalPriceText), total > 0, cash < total {
                            Text("Not enough cash. You have \(String(format: "$%.2f", cash)).")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AppTheme.textError)
                        }
                    }
                    .padding(AppTheme.cardPadding)
                }
            }
            .navigationTitle("New Buy Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.cardBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        viewModel.showNewBuyOrderSheet = false
                    }
                    .foregroundStyle(AppTheme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Post") {
                        viewModel.postBuyOrder()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.chipReady)
                    .disabled(viewModel.newOrderPosting)
                }
            }
            .onAppear {
                viewModel.loadBuyOrders()
            }
            .overlay {
                if viewModel.newOrderPosting {
                    ProgressView("Posting...")
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                }
            }
        }
    }

    @ViewBuilder
    private func newOrderLineRow(index: Int) -> some View {
        if index >= viewModel.newOrderLines.count { EmptyView() }
        else {
        let line = viewModel.newOrderLines[index]
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Resource \(index + 1)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textTertiary)
                Spacer()
                if viewModel.newOrderLines.count > 1 {
                    Button("Remove") {
                        viewModel.removeNewOrderLine(at: IndexSet(integer: index))
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textError)
                }
            }
            Menu {
                ForEach(MarketCatalog.tradeableItems(), id: \.id) { item in
                    Button(item.name) {
                        viewModel.setNewOrderLineItem(index: index, item: item)
                    }
                }
            } label: {
                HStack {
                    Text(line.item?.name ?? "Select resource")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(line.item != nil ? AppTheme.textPrimary : AppTheme.textTertiary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AppTheme.cardBackgroundAlt)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quality")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.textTertiary)
                    Picker("", selection: Binding(
                        get: { line.quality },
                        set: { viewModel.setNewOrderLineQuality(index: index, quality: $0) }
                    )) {
                        ForEach(1...5, id: \.self) { q in
                            Text("Q\(q)").tag(q)
                        }
                    }
                    .pickerStyle(.menu)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quantity")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.textTertiary)
                    TextField("Units", text: Binding(
                        get: { line.quantityText },
                        set: { viewModel.setNewOrderLineQuantity(index: index, text: $0) }
                    ))
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                }
            }
        }
        .padding(12)
        .background(AppTheme.cardBackground.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        }
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
                    row("Current Bid", String(format: "$%.2f", listing.currentBid))
                    row("Buy Now", String(format: "$%.2f", listing.buyNowPrice))
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

                Form {
                    Section("Place Bid") {
                        Text(viewModel.mineLabel(for: listing.resourceType))
                        Text(String(format: "Current Bid: $%.2f", listing.currentBid))
                        Text(String(format: "Buy Now: $%.2f", listing.buyNowPrice))
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
