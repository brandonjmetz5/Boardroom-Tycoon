import SwiftUI

struct BuyOrderMarketView: View {
    let userID: String

    @StateObject private var viewModel: MarketViewModel

    init(userID: String) {
        self.userID = userID
        _viewModel = StateObject(wrappedValue: MarketViewModel(userID: userID))
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            buyOrdersContent
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Buy Order Market")
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
            viewModel.loadBuyOrders()
        }
        .sheet(isPresented: $viewModel.showNewBuyOrderSheet) {
            newBuyOrderSheet
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

    // MARK: - Content

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
        .onAppear {
            viewModel.loadAggregatesIfNeeded()
        }
    }

    private func buyOrderCard(order: BuyOrder) -> some View {
        let canFulfill = viewModel.canFulfill(order)
        let delta = viewModel.dealDeltaForBuyOrder(order)
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
                    if let delta {
                        let text = String(format: "%+.0f%% vs selling", delta)
                        Text(text)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(delta >= 0 ? AppTheme.chipPositive : AppTheme.textError)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                (delta >= 0 ? AppTheme.chipPositive : AppTheme.textError)
                                    .opacity(0.15)
                            )
                            .clipShape(Capsule())
                    }
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

    // MARK: - New buy order sheet

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
}

