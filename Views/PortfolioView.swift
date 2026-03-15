//
//  PortfolioView.swift
//  Boardroom Tycoon
//
//  Portfolio: stocks list and trade sheet.
//

import SwiftUI

struct PortfolioView: View {
    let userID: String

    @State private var portfolioSegment = 0
    @StateObject private var stocksVM: StocksViewModel

    init(userID: String) {
        self.userID = userID
        _stocksVM = StateObject(wrappedValue: StocksViewModel(userID: userID))
    }

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Picker("Section", selection: $portfolioSegment) {
                    Text("Stocks").tag(0)
                    Text("My Positions").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, AppTheme.horizontalPadding)
                .padding(.vertical, 12)

                if portfolioSegment == 0 {
                    stocksContent
                } else {
                    positionsContent
                }
            }
        }
        .sheet(item: $stocksVM.selectedStockForTrade) { stock in
            stockTradeSheet(stock: stock)
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
                        if stocksVM.canTrade && !stocksVM.positions.isEmpty {
                            portfolioSummaryCard
                        }
                        if stocksVM.canTrade && stocksVM.positions.isEmpty && !stocksVM.stocks.isEmpty {
                            noPositionsHint
                        }
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
    }

    private var positionsContent: some View {
        Group {
            if stocksVM.isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(1.1)
                    .tint(AppTheme.accent)
                Text("Loading...")
                    .font(AppTheme.caption())
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
            } else if stocksVM.positionsWithStock.isEmpty {
                emptyState(
                    title: "No positions",
                    message: "You don't have any holdings yet. Tap Stocks to buy."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if stocksVM.canTrade {
                            portfolioSummaryCard
                        }
                        ForEach(stocksVM.positionsWithStock, id: \.position.id) { item in
                            Button {
                                if stocksVM.canTrade {
                                    stocksVM.openTradeSheet(for: item.stock, preferSell: true)
                                }
                            } label: {
                                positionRow(position: item.position, stock: item.stock)
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
    }

    private func positionRow(position: StockPosition, stock: Stock) -> some View {
        let marketValue = position.sharesOwned * stock.currentPrice
        let costBasis = position.sharesOwned * position.averageCost
        let pl = marketValue - costBasis

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stock.name)
                        .font(AppTheme.bodyMedium())
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(stock.symbol)
                        .font(AppTheme.caption())
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("\(String(format: "%.2f", position.sharesOwned)) shares")
                        .font(AppTheme.captionMedium())
                        .foregroundStyle(AppTheme.textTertiary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "$%.2f", marketValue))
                        .font(AppTheme.monoNumber())
                        .foregroundStyle(AppTheme.accent)
                    Text("Avg cost \(String(format: "$%.2f", position.averageCost))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.textTertiary)
                    HStack(spacing: 4) {
                        Text(pl >= 0 ? "+" : "")
                            .font(AppTheme.captionMedium())
                            .foregroundStyle(pl >= 0 ? AppTheme.chipPositive : AppTheme.chipNegative)
                        Text(String(format: "$%.2f", abs(pl)))
                            .font(AppTheme.captionMedium())
                            .foregroundStyle(pl >= 0 ? AppTheme.chipPositive : AppTheme.chipNegative)
                        Text(pl >= 0 ? "gain" : "loss")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(pl >= 0 ? AppTheme.chipPositive : AppTheme.chipNegative)
                    }
                }
            }
            HStack(spacing: 12) {
                Text("Price now: \(String(format: "$%.2f", stock.currentPrice))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                if stocksVM.canTrade {
                    Spacer()
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

    private var portfolioSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Portfolio value")
                .font(AppTheme.caption())
                .foregroundStyle(AppTheme.textSecondary)
            Text(String(format: "$%.2f", stocksVM.portfolioValue))
                .font(AppTheme.titleSmall())
                .foregroundStyle(AppTheme.textPrimary)
            HStack(spacing: 4) {
                Text("Today")
                    .font(AppTheme.captionMedium())
                    .foregroundStyle(AppTheme.textTertiary)
                Text(stocksVM.todayPL >= 0 ? "+" : "")
                    .font(AppTheme.captionMedium())
                    .foregroundStyle(stocksVM.todayPL >= 0 ? AppTheme.chipPositive : AppTheme.chipNegative)
                Text(String(format: "$%.2f", abs(stocksVM.todayPL)))
                    .font(AppTheme.captionMedium())
                    .foregroundStyle(stocksVM.todayPL >= 0 ? AppTheme.chipPositive : AppTheme.chipNegative)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.cardPadding)
        .appCard()
    }

    private var noPositionsHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.accent)
            Text("You don't own any shares yet. Tap a stock to buy.")
                .font(AppTheme.caption())
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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

    private func chartTitleForTimeFrame(_ tf: ChartTimeFrame) -> String {
        switch tf {
        case .oneMin: return "1 min"
        case .fiveMin: return "5 min"
        case .fifteenMin: return "15 min"
        case .oneHour: return "1 hour"
        case .oneDay: return "1 day"
        case .all: return "30 days"
        }
    }

    private func stockRow(stock: Stock) -> some View {
        HStack(alignment: .center, spacing: 12) {
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
            if !stocksVM.sparklinePoints(for: stock.symbol).isEmpty {
                SparklineView(
                    points: stocksVM.sparklinePoints(for: stock.symbol),
                    lineColor: stock.priceChange >= 0 ? AppTheme.chipPositive : AppTheme.chipNegative
                )
                .frame(width: 56, height: 28)
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

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(stock.name)
                                        .font(AppTheme.bodyMedium())
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Text(stock.symbol)
                                        .font(AppTheme.caption())
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(String(format: "$%.2f", stock.currentPrice))
                                        .font(AppTheme.monoNumber())
                                        .foregroundStyle(AppTheme.accent)
                                    Text(stocksVM.formattedChange(stock.priceChange))
                                        .font(AppTheme.caption())
                                        .foregroundStyle(stock.priceChange >= 0 ? AppTheme.chipPositive : AppTheme.chipNegative)
                                }
                            }
                            .padding(AppTheme.cardPadding)
                            .appCard()

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(ChartTimeFrame.allCases) { tf in
                                        Button {
                                            stocksVM.changeChartTimeFrame(to: tf)
                                        } label: {
                                            Text(tf.displayName)
                                                .font(AppTheme.captionMedium())
                                                .foregroundStyle(stocksVM.selectedChartTimeFrame == tf ? AppTheme.background : AppTheme.textSecondary)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(stocksVM.selectedChartTimeFrame == tf ? AppTheme.accent : Color.clear)
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 4)
                            }

                            StockChartView(
                                points: stocksVM.priceHistory,
                                title: chartTitleForTimeFrame(stocksVM.selectedChartTimeFrame),
                                isLoading: stocksVM.isPriceHistoryLoading
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, AppTheme.horizontalPadding)
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Action", selection: $stocksVM.tradeSegment) {
                            Text("Buy").tag(0)
                            Text("Sell").tag(1)
                        }
                        .pickerStyle(.segmented)

                        if stocksVM.tradeSegment == 0, let cash = stocksVM.profile?.cash {
                            Text("Cash: \(String(format: "$%.2f", cash))")
                                .font(AppTheme.caption())
                                .foregroundStyle(AppTheme.textSecondary)
                        } else if let pos = stocksVM.position(for: stock.symbol) {
                            Text("You own: \(String(format: "%.2f", pos.sharesOwned)) shares")
                                .font(AppTheme.caption())
                                .foregroundStyle(AppTheme.textSecondary)
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
                    .padding(.vertical, 16)
                    .background(AppTheme.background)
                }

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

}

#Preview {
    NavigationStack {
        PortfolioView(userID: "preview-user")
    }
}
