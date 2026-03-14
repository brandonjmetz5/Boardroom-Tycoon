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
        _stocksVM = StateObject(wrappedValue: StocksViewModel())
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
                            stockRow(stock)
                        }
                    }
                    .padding(.horizontal, AppTheme.horizontalPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
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

    private func stockRow(_ stock: Stock) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(stock.name)
                    .font(AppTheme.bodyMedium())
                    .foregroundStyle(AppTheme.textPrimary)
                Text(stock.symbol)
                    .font(AppTheme.caption())
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "$%.2f", stock.currentPrice))
                    .font(AppTheme.monoNumber())
                    .foregroundStyle(AppTheme.textPrimary)
                Text(stocksVM.formattedChange(stock.priceChange))
                    .font(AppTheme.captionMedium())
                    .foregroundStyle(stock.priceChange >= 0 ? AppTheme.chipPositive : AppTheme.chipNegative)
            }
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
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
