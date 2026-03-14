//
//  PortfolioView.swift
//  Boardroom Tycoon
//
//  Combined Stocks + Inventory with segment control.
//

import SwiftUI

struct PortfolioView: View {
    let userID: String

    @State private var segment = 0
    @StateObject private var stocksVM: StocksViewModel
    @StateObject private var inventoryVM: InventoryViewModel

    init(userID: String) {
        self.userID = userID
        _stocksVM = StateObject(wrappedValue: StocksViewModel(userID: userID))
        _inventoryVM = StateObject(wrappedValue: InventoryViewModel(userID: userID))
    }

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Picker("Section", selection: $segment) {
                    Text("Stocks").tag(0)
                    Text("Inventory").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, AppTheme.horizontalPadding)
                .padding(.vertical, 12)

                if segment == 0 {
                    stocksContent
                } else {
                    inventoryContent
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Portfolio")
                    .font(AppTheme.titleMedium())
                    .foregroundStyle(AppTheme.textPrimary)
            }
        }
        .onAppear {
            stocksVM.loadStocks()
            inventoryVM.loadInventory()
        }
    }

    private var stocksContent: some View {
        Group {
            if stocksVM.isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(1.1)
                    .tint(AppTheme.accent)
                Text("Loading stocks...")
                    .font(AppTheme.caption())
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
            } else if let err = stocksVM.errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Failed to load stocks")
                        .font(AppTheme.bodyMedium())
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(err)
                        .font(AppTheme.caption())
                        .foregroundStyle(AppTheme.textError)
                }
                .padding(AppTheme.cardPadding)
                .frame(maxWidth: .infinity)
                .appCard()
                .padding(.horizontal)
                .padding(.top, 20)
            } else if stocksVM.stocks.isEmpty {
                emptyState(
                    title: "No stocks yet",
                    message: "Sector stocks will appear here when added."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(stocksVM.stocks) { stock in
                            Button {
                                if stocksVM.canTrade {
                                    stocksVM.openTradeSheet(for: stock)
                                }
                            } label: {
                                stockRow(stock: stock)
                            }
                            .buttonStyle(.plain)
                            .disabled(!stocksVM.canTrade)
                        }
                    }
                    .padding(.horizontal, AppTheme.horizontalPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
        }
        .sheet(item: $stocksVM.selectedStockForTrade) { stock in
            stockTradeSheet(stock: stock)
        }
    }

    private var inventoryContent: some View {
        Group {
            if inventoryVM.isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(1.1)
                    .tint(AppTheme.accent)
                Text("Loading inventory...")
                    .font(AppTheme.caption())
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
            } else if let err = inventoryVM.errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Failed to load inventory")
                        .font(AppTheme.bodyMedium())
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(err)
                        .font(AppTheme.caption())
                        .foregroundStyle(AppTheme.textError)
                }
                .padding(AppTheme.cardPadding)
                .frame(maxWidth: .infinity)
                .appCard()
                .padding(.horizontal)
                .padding(.top, 20)
            } else if inventoryVM.inventoryItems.isEmpty {
                emptyState(
                    title: "No items",
                    message: "Your inventory will show here once you have items."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(inventoryVM.inventoryItems) { item in
                            inventoryRow(item)
                        }
                    }
                    .padding(.horizontal, AppTheme.horizontalPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private func emptyState(title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.textTertiary)
            Text(title)
                .font(AppTheme.bodyMedium())
                .foregroundStyle(AppTheme.textPrimary)
            Text(message)
                .font(AppTheme.caption())
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal, 24)
    }

    private func stockRow(stock: Stock) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(stock.name)
                    .font(AppTheme.bodyMedium())
                    .foregroundStyle(AppTheme.textPrimary)
                Text(stock.symbol)
                    .font(AppTheme.caption())
                    .foregroundStyle(AppTheme.textSecondary)
                if let pos = stocksVM.position(for: stock.symbol), pos.sharesOwned > 0 {
                    Text("Own \(String(format: "%.2f", pos.sharesOwned)) shares")
                        .font(AppTheme.captionMedium())
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "$%.2f", stock.currentPrice))
                    .font(AppTheme.monoNumber())
                    .foregroundStyle(AppTheme.textPrimary)
                Text(stocksVM.formattedChange(stock.priceChange))
                    .font(AppTheme.captionMedium())
                    .foregroundStyle(stock.priceChange >= 0 ? AppTheme.chipPositive : AppTheme.chipNegative)
                if stocksVM.canTrade {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private func stockTradeSheet(stock: Stock) -> some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(stock.name)
                            .font(AppTheme.titleSmall())
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(stock.symbol)
                            .font(AppTheme.caption())
                            .foregroundStyle(AppTheme.textSecondary)
                        Text(String(format: "$%.2f", stock.currentPrice))
                            .font(AppTheme.monoNumber())
                            .foregroundStyle(AppTheme.accent)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppTheme.cardPadding)
                    .appCard()

                    Picker("Action", selection: $stocksVM.tradeSegment) {
                        Text("Buy").tag(0)
                        Text("Sell").tag(1)
                    }
                    .pickerStyle(.segmented)

                    if stocksVM.tradeSegment == 0 {
                        if let cash = stocksVM.profile?.cash {
                            Text("Cash: \(String(format: "$%.2f", cash))")
                                .font(AppTheme.caption())
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    } else {
                        if let pos = stocksVM.position(for: stock.symbol) {
                            Text("You own: \(String(format: "%.2f", pos.sharesOwned)) shares")
                                .font(AppTheme.caption())
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }

                    TextField("Shares", text: $stocksVM.tradeQuantityText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .padding(.vertical, 4)

                    if let total = stocksVM.tradeTotal() {
                        Text(stocksVM.tradeSegment == 0 ? "Cost: \(String(format: "$%.2f", total))" : "Proceeds: \(String(format: "$%.2f", total))")
                            .font(AppTheme.bodyMedium())
                            .foregroundStyle(AppTheme.accent)
                    }

                    if let err = stocksVM.tradeErrorMessage {
                        Text(err)
                            .font(AppTheme.caption())
                            .foregroundStyle(AppTheme.textError)
                    }

                    Button {
                        stocksVM.submitTrade()
                    } label: {
                        Text(stocksVM.tradeSegment == 0 ? "Buy" : "Sell")
                            .font(AppTheme.bodyMedium())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .disabled(stocksVM.isSubmitting || stocksVM.parsedTradeQuantity <= 0)
                    .opacity(stocksVM.isSubmitting ? 0.7 : 1)
                }
                .padding(AppTheme.horizontalPadding)

                if stocksVM.isSubmitting {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(AppTheme.accent)
                }
            }
            .navigationTitle(stocksVM.tradeSegment == 0 ? "Buy \(stock.symbol)" : "Sell \(stock.symbol)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.surface, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        stocksVM.closeTradeSheet()
                    }
                    .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
    }

    private func inventoryRow(_ item: InventoryItem) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.item.name)
                    .font(AppTheme.bodyMedium())
                    .foregroundStyle(AppTheme.textPrimary)
                Text(item.item.category.rawValue)
                    .font(AppTheme.caption())
                    .foregroundStyle(AppTheme.textTertiary)
            }
            Spacer()
            Text(inventoryVM.formattedQuantity(for: item))
                .font(AppTheme.monoNumber())
                .foregroundStyle(AppTheme.accent)
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }
}

#Preview {
    NavigationStack {
        PortfolioView(userID: "preview-user")
    }
}
