//
//  PortfolioView.swift
//  Boardroom Tycoon
//
//  Stocks + positions command console.
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
            AppTheme.background.ignoresSafeArea()
            LinearGradient(
                colors: [AppTheme.surface.opacity(0.12), Color.clear, AppTheme.surface.opacity(0.10)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                segmentRail
                if portfolioSegment == 0 { stocksContent } else { positionsContent }
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
        .onAppear { stocksVM.loadStocks() }
    }

    private var segmentRail: some View {
        PortfolioRail(title: "Trading Console", systemImage: "chart.line.uptrend.xyaxis", tone: .priority) {
            Picker("Section", selection: $portfolioSegment) {
                Text("Stocks").tag(0)
                Text("My Positions").tag(1)
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, AppTheme.horizontalPadding)
        .padding(.top, 10)
    }

    private var stocksContent: some View {
        Group {
            if stocksVM.isLoading {
                Spacer()
                ProgressView().scaleEffect(1.1).tint(AppTheme.accent)
                Text("Loading stocks...").font(AppTheme.caption()).foregroundStyle(AppTheme.textSecondary)
                Spacer()
            } else if let err = stocksVM.errorMessage {
                PortfolioRail(title: "Load Failure", systemImage: "exclamationmark.triangle.fill", tone: .priority) {
                    Text(err).font(AppTheme.caption()).foregroundStyle(AppTheme.textError)
                }
                .padding(.horizontal, AppTheme.horizontalPadding)
                .padding(.top, 12)
            } else if stocksVM.stocks.isEmpty {
                emptyState(title: "No stocks yet", message: "Sector stocks will appear here when added.")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        headerRail
                        if stocksVM.canTrade && !stocksVM.positions.isEmpty { portfolioSummaryRail }
                        if stocksVM.canTrade && stocksVM.positions.isEmpty && !stocksVM.stocks.isEmpty { noPositionsHint }

                        PortfolioRail(title: "Market Board", systemImage: "building.columns.fill") {
                            LazyVStack(spacing: 9) {
                                ForEach(stocksVM.stocks) { stock in
                                    Button {
                                        if stocksVM.canTrade { stocksVM.openTradeSheet(for: stock) }
                                    } label: {
                                        stockRow(stock: stock)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(!stocksVM.canTrade)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.horizontalPadding)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private var positionsContent: some View {
        Group {
            if stocksVM.isLoading {
                Spacer()
                ProgressView().scaleEffect(1.1).tint(AppTheme.accent)
                Text("Loading...").font(AppTheme.caption()).foregroundStyle(AppTheme.textSecondary)
                Spacer()
            } else if stocksVM.positionsWithStock.isEmpty {
                emptyState(title: "No positions", message: "You don't have any holdings yet. Tap Stocks to buy.")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        headerRail
                        if stocksVM.canTrade { portfolioSummaryRail }
                        PortfolioRail(title: "Position Ledger", systemImage: "briefcase.fill") {
                            LazyVStack(spacing: 9) {
                                ForEach(stocksVM.positionsWithStock, id: \.position.id) { item in
                                    Button {
                                        if stocksVM.canTrade { stocksVM.openTradeSheet(for: item.stock, preferSell: true) }
                                    } label: {
                                        positionRow(position: item.position, stock: item.stock)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(!stocksVM.canTrade)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.horizontalPadding)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private var headerRail: some View {
        PortfolioRail(title: "Desk Status", systemImage: "dot.radiowaves.left.and.right") {
            HStack(spacing: 10) {
                metricPill("SYMBOLS", "\(stocksVM.stocks.count)", AppTheme.accent)
                metricPill("POSITIONS", "\(stocksVM.positionsWithStock.count)", AppTheme.chipAvailable)
                metricPill("MODE", stocksVM.canTrade ? "LIVE" : "READ-ONLY", stocksVM.canTrade ? AppTheme.chipReady : AppTheme.chipIdle)
            }
        }
    }

    private func metricPill(_ title: String, _ value: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.textTertiary)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(tint)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.surfaceAlt.opacity(0.58)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border.opacity(0.95), lineWidth: 1))
    }

    private func stockRow(stock: Stock) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(stock.name).font(AppTheme.bodyMedium()).foregroundStyle(AppTheme.textPrimary)
                Text(stock.symbol).font(AppTheme.caption()).foregroundStyle(AppTheme.textSecondary)
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
        .padding(11)
        .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.surfaceAlt.opacity(0.58)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border.opacity(0.95), lineWidth: 1))
    }

    private func positionRow(position: StockPosition, stock: Stock) -> some View {
        let marketValue = position.sharesOwned * stock.currentPrice
        let costBasis = position.sharesOwned * position.averageCost
        let pl = marketValue - costBasis
        let color = pl >= 0 ? AppTheme.chipPositive : AppTheme.chipNegative

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(stock.name).font(AppTheme.bodyMedium()).foregroundStyle(AppTheme.textPrimary)
                    Text(stock.symbol).font(AppTheme.caption()).foregroundStyle(AppTheme.textSecondary)
                    Text("\(String(format: "%.2f", position.sharesOwned)) shares")
                        .font(AppTheme.captionMedium())
                        .foregroundStyle(AppTheme.textTertiary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(String(format: "$%.2f", marketValue))
                        .font(AppTheme.monoNumber())
                        .foregroundStyle(AppTheme.accent)
                    Text("Avg \(String(format: "$%.2f", position.averageCost))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.textTertiary)
                    Text("\(pl >= 0 ? "+" : "-")$\(String(format: "%.2f", abs(pl)))")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(color)
                }
            }
            HStack {
                Text("Now \(String(format: "$%.2f", stock.currentPrice))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                if stocksVM.canTrade {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }
        }
        .padding(11)
        .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.surfaceAlt.opacity(0.58)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border.opacity(0.95), lineWidth: 1))
    }

    private var portfolioSummaryRail: some View {
        PortfolioRail(title: "Portfolio Snapshot", systemImage: "chart.pie.fill", tone: .priority) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Portfolio value")
                    .font(AppTheme.caption())
                    .foregroundStyle(AppTheme.textSecondary)
                Text(String(format: "$%.2f", stocksVM.portfolioValue))
                    .font(AppTheme.titleSmall())
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Today \(stocksVM.todayPL >= 0 ? "+" : "-")$\(String(format: "%.2f", abs(stocksVM.todayPL)))")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(stocksVM.todayPL >= 0 ? AppTheme.chipPositive : AppTheme.chipNegative)
            }
        }
    }

    private var noPositionsHint: some View {
        PortfolioRail(title: "Hint", systemImage: "hand.tap.fill") {
            Text("You don't own any shares yet. Tap a stock to buy.")
                .font(AppTheme.caption())
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private func emptyState(title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundStyle(AppTheme.textTertiary)
            Text(title).font(AppTheme.bodyMedium()).foregroundStyle(AppTheme.textPrimary)
            Text(message).font(AppTheme.caption()).foregroundStyle(AppTheme.textSecondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal, 24)
    }

    private func chartTitleForTimeFrame(_ tf: ChartTimeFrame) -> String { tf.displayName }

    private func timeFrameIcon(_ tf: ChartTimeFrame) -> String {
        switch tf {
        case .oneHour: return "clock"
        case .oneDay: return "sun.max"
        case .oneWeek: return "calendar"
        case .allTime: return "infinity"
        }
    }

    private func stockTradeSheet(stock: Stock) -> some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            PortfolioRail(title: "Order Ticket", systemImage: "chart.line.uptrend.xyaxis", tone: .priority) {
                                HStack(alignment: .center, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(stock.name).font(AppTheme.bodyMedium()).foregroundStyle(AppTheme.textPrimary)
                                        Text(stock.symbol).font(AppTheme.caption()).foregroundStyle(AppTheme.textSecondary)
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
                            }

                            PortfolioRail(title: "Chart Window", systemImage: "waveform.path.ecg") {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(ChartTimeFrame.allCases) { tf in
                                            Button {
                                                stocksVM.changeChartTimeFrame(to: tf)
                                            } label: {
                                                let selected = stocksVM.selectedChartTimeFrame == tf
                                                HStack(spacing: 8) {
                                                    Image(systemName: timeFrameIcon(tf))
                                                        .font(.system(size: 12, weight: .semibold))
                                                    Text(tf.displayName)
                                                        .font(AppTheme.captionMedium())
                                                }
                                                .foregroundStyle(selected ? AppTheme.background : AppTheme.textSecondary)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(selected ? AppTheme.accent.opacity(0.92) : AppTheme.surfaceAlt.opacity(0.45))
                                                .overlay(RoundedRectangle(cornerRadius: 999).stroke(selected ? AppTheme.accent.opacity(0.2) : AppTheme.border, lineWidth: 1))
                                                .clipShape(Capsule())
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }

                                StockChartView(
                                    points: stocksVM.priceHistory,
                                    title: chartTitleForTimeFrame(stocksVM.selectedChartTimeFrame),
                                    isLoading: stocksVM.isPriceHistoryLoading
                                )
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal, AppTheme.horizontalPadding)
                        .padding(.top, 8)
                        .padding(.bottom, 18)
                    }

                    PortfolioRail(title: "Execution", systemImage: "bolt.fill", tone: .priority) {
                        VStack(alignment: .leading, spacing: 10) {
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
                                .tint(AppTheme.accent)
                                .foregroundStyle(AppTheme.textPrimary)
                                .font(AppTheme.monoNumber())
                                .padding(.vertical, 12)
                                .padding(.horizontal, 14)
                                .background(AppTheme.surfaceAlt.opacity(0.58))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border, lineWidth: 1))
                                .clipShape(RoundedRectangle(cornerRadius: 10))

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
                                    .padding(.vertical, 13)
                                    .background(AppTheme.accent)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .disabled(stocksVM.isSubmitting || stocksVM.parsedTradeQuantity <= 0)
                            .opacity(stocksVM.isSubmitting ? 0.7 : 1)
                        }
                    }
                    .padding(.horizontal, AppTheme.horizontalPadding)
                    .padding(.vertical, 12)
                }

                if stocksVM.isSubmitting {
                    ProgressView().scaleEffect(1.2).tint(AppTheme.accent)
                }
            }
            .navigationTitle(stocksVM.tradeSegment == 0 ? "Buy \(stock.symbol)" : "Sell \(stock.symbol)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.surface, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { stocksVM.closeTradeSheet() }
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
    }
}

private enum PortfolioRailTone {
    case normal
    case priority
}

private struct PortfolioRail<Content: View>: View {
    let title: String
    let systemImage: String
    var tone: PortfolioRailTone
    private let content: Content

    init(title: String, systemImage: String, tone: PortfolioRailTone = .normal, @ViewBuilder content: () -> Content) {
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

#Preview {
    NavigationStack {
        PortfolioView(userID: "preview-user")
    }
}
