//
//  StocksViewModel.swift
//  Boardroom Tycoon
//
//  Stocks list, positions, and buy/sell trading. Pass userID for trading; omit for read-only.
//

import Foundation
import Combine

@MainActor
final class StocksViewModel: ObservableObject {
    let userID: String?

    @Published private(set) var stocks: [Stock] = []
    @Published private(set) var positions: [StockPosition] = []
    @Published private(set) var profile: PlayerProfile?
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?

    @Published var selectedStockForTrade: Stock?
    @Published private(set) var priceHistory: [StockPricePoint] = []
    @Published private(set) var isPriceHistoryLoading = false
    @Published var selectedChartTimeFrame: ChartTimeFrame = .oneDay
    @Published private(set) var sparklineData: [String: [StockPricePoint]] = [:]
    @Published var tradeQuantityText = ""
    @Published var tradeSegment = 0 // 0 = Buy, 1 = Sell
    @Published private(set) var isSubmitting = false
    @Published var tradeErrorMessage: String?

    private let stockService = StockService()
    private let positionService = StockPositionService()
    private let profileService = PlayerProfileService()
    private let transactionService = TransactionService()
    private var refreshTimer: Timer?
    private let refreshInterval: TimeInterval = 12

    init(userID: String? = nil) {
        self.userID = userID
    }

    var canTrade: Bool { userID != nil }

    func position(for symbol: String) -> StockPosition? {
        positions.first { $0.symbol == symbol }
    }

    func loadStocks() {
        startLiveRefresh()
        isLoading = true
        errorMessage = nil
        stockService.fetchStocks { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let list):
                    self.stocks = list
                    self.loadSparklines()
                    if self.userID != nil {
                        self.loadPositionsAndProfile()
                    } else {
                        self.isLoading = false
                    }
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    func startLiveRefresh() {
        stockService.observeStocks { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let list):
                    self.stocks = list
                    self.loadSparklines(forceReload: true)
                    if self.selectedStockForTrade != nil {
                        self.syncSelectedStockFromLatestList()
                        self.loadPriceHistoryForSelectedStock(showLoading: false)
                    }
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }

        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshForLiveView()
            }
        }
    }

    func stopLiveRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        stockService.stopObservingStocks()
    }

    private func loadPositionsAndProfile() {
        guard let uid = userID else { isLoading = false; return }
        let group = DispatchGroup()

        group.enter()
        positionService.fetchStockPositions(for: uid) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let list): self?.positions = list
                case .failure: break
                }
                group.leave()
            }
        }

        group.enter()
        profileService.fetchPlayerProfile(for: uid) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let p): self?.profile = p
                case .failure: break
                }
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            self?.isLoading = false
        }
    }

    /// Positions with matching stock info (for My Positions tab). Only includes positions we have price data for.
    var positionsWithStock: [(position: StockPosition, stock: Stock)] {
        positions.compactMap { pos in
            guard let stock = stocks.first(where: { $0.symbol == pos.symbol }) else { return nil }
            return (position: pos, stock: stock)
        }
    }

    func openTradeSheet(for stock: Stock, preferSell: Bool = false) {
        selectedStockForTrade = stock
        tradeQuantityText = ""
        tradeErrorMessage = nil
        tradeSegment = preferSell ? 1 : 0
        priceHistory = []
        isPriceHistoryLoading = true
        loadPriceHistoryForSelectedStock(showLoading: true)
    }

    func closeTradeSheet() {
        selectedStockForTrade = nil
        priceHistory = []
        isPriceHistoryLoading = false
        tradeQuantityText = ""
        tradeErrorMessage = nil
    }

    /// Call when user changes timeframe; reloads chart for current stock.
    func changeChartTimeFrame(to timeFrame: ChartTimeFrame) {
        selectedChartTimeFrame = timeFrame
        loadPriceHistoryForSelectedStock(showLoading: true)
    }

    private func loadPriceHistoryForSelectedStock(showLoading: Bool) {
        guard let stock = selectedStockForTrade else { return }
        if showLoading {
            isPriceHistoryLoading = true
        }
        stockService.fetchPriceHistory(for: stock, timeFrame: selectedChartTimeFrame) { [weak self] points in
            DispatchQueue.main.async {
                self?.priceHistory = points
                if showLoading {
                    self?.isPriceHistoryLoading = false
                }
            }
        }
    }

    private func loadSparklines(forceReload: Bool = false) {
        // Prefer real history for sparklines (so portfolio rows match chart direction).
        var data = sparklineData
        let group = DispatchGroup()

        for stock in stocks {
            if !forceReload, data[stock.symbol] != nil { continue }

            group.enter()
            stockService.fetchRecentHistoryPoints(symbol: stock.symbol, count: 7) { [weak self] points in
                let final: [StockPricePoint]
                if points.isEmpty {
                    final = StockService.generateFakeHistory(symbol: stock.symbol, currentPrice: stock.currentPrice, count: 7)
                } else {
                    final = points
                }

                Task { @MainActor in
                    data[stock.symbol] = final
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            self?.sparklineData = data
        }
    }

    func sparklinePoints(for symbol: String) -> [StockPricePoint] {
        sparklineData[symbol] ?? []
    }

    /// Total market value of all positions at current prices.
    var portfolioValue: Double {
        positions.reduce(0) { sum, pos in
            guard let stock = stocks.first(where: { $0.symbol == pos.symbol }) else { return sum }
            return sum + pos.sharesOwned * stock.currentPrice
        }
    }

    /// Estimated today's P&L (positions × price change per share).
    var todayPL: Double {
        positions.reduce(0) { sum, pos in
            guard let stock = stocks.first(where: { $0.symbol == pos.symbol }) else { return sum }
            return sum + pos.sharesOwned * stock.priceChange
        }
    }

    func buyStock() {
        guard let stock = selectedStockForTrade, let uid = userID else { return }
        let shares = parseQuantity(tradeQuantityText)
        guard shares > 0 else {
            tradeErrorMessage = "Enter a valid number of shares."
            return
        }
        let cash = profile?.cash ?? 0
        let cost = shares * stock.currentPrice
        if cost > cash {
            tradeErrorMessage = "Not enough cash. Need \(NumberFormatting.currency(cost, fractionDigits: 2)), have \(NumberFormatting.currency(cash, fractionDigits: 2))."
            return
        }

        isSubmitting = true
        tradeErrorMessage = nil
        positionService.buyStock(
            userID: uid,
            symbol: stock.symbol,
            shares: shares,
            pricePerShare: stock.currentPrice,
            totalShares: stock.totalShares,
            maxOwnershipPercent: stock.maxOwnershipPercent
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isSubmitting = false
                switch result {
                case .success:
                    self.recordTransaction(type: "stock_buy", amount: -cost, description: "Bought \(NumberFormatting.decimal(shares, fractionDigits: 2)) \(stock.symbol)")
                    self.loadPositionsAndProfile()
                    self.closeTradeSheet()
                case .failure(let error):
                    self.tradeErrorMessage = error.localizedDescription
                }
            }
        }
    }

    func sellStock() {
        guard let stock = selectedStockForTrade, let uid = userID else { return }
        let shares = parseQuantity(tradeQuantityText)
        guard shares > 0 else {
            tradeErrorMessage = "Enter a valid number of shares."
            return
        }
        let pos = position(for: stock.symbol)
        let owned = pos?.sharesOwned ?? 0
        if shares > owned {
            tradeErrorMessage = "You own \(NumberFormatting.decimal(owned, fractionDigits: 2)) shares. Cannot sell more."
            return
        }

        isSubmitting = true
        tradeErrorMessage = nil
        positionService.sellStock(userID: uid, symbol: stock.symbol, shares: shares, pricePerShare: stock.currentPrice) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isSubmitting = false
                switch result {
                case .success:
                    let proceeds = shares * stock.currentPrice
                    self.recordTransaction(type: "stock_sell", amount: proceeds, description: "Sold \(NumberFormatting.decimal(shares, fractionDigits: 2)) \(stock.symbol)")
                    self.loadPositionsAndProfile()
                    self.closeTradeSheet()
                case .failure(let error):
                    self.tradeErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private func recordTransaction(type: String, amount: Double, description: String) {
        guard let uid = userID else { return }
        transactionService.createTransaction(userID: uid, type: type, amount: amount, description: description) { _ in }
    }

    func submitTrade() {
        if tradeSegment == 0 {
            buyStock()
        } else {
            sellStock()
        }
    }

    private func parseQuantity(_ text: String) -> Double {
        guard let value = NumberFormatting.parseDecimalInput(text) else { return 0 }
        return max(0, value)
    }

    /// Parsed trade quantity from tradeQuantityText (for UI disabled state etc.).
    var parsedTradeQuantity: Double { parseQuantity(tradeQuantityText) }

    /// Total cost for current trade quantity (buy) or proceeds (sell). Uses selected stock and tradeQuantityText.
    func tradeTotal() -> Double? {
        guard let stock = selectedStockForTrade else { return nil }
        let q = parseQuantity(tradeQuantityText)
        guard q > 0 else { return nil }
        return q * stock.currentPrice
    }

    func formattedChange(_ change: Double) -> String {
        NumberFormatting.signedCurrency(change, fractionDigits: 2)
    }

    private func refreshForLiveView() {
        stockService.fetchStocks { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                if case .success(let list) = result {
                    self.stocks = list
                    self.loadSparklines(forceReload: true)
                    if self.selectedStockForTrade != nil {
                        self.syncSelectedStockFromLatestList()
                        self.loadPriceHistoryForSelectedStock(showLoading: false)
                    }
                }
            }
        }

        if userID != nil {
            loadPositionsAndProfile()
        }
    }

    private func syncSelectedStockFromLatestList() {
        guard let current = selectedStockForTrade else { return }
        guard let latest = stocks.first(where: { $0.symbol == current.symbol }) else { return }
        selectedStockForTrade = latest
    }
}
