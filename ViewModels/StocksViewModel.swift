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
    @Published var tradeQuantityText = ""
    @Published var tradeSegment = 0 // 0 = Buy, 1 = Sell
    @Published private(set) var isSubmitting = false
    @Published var tradeErrorMessage: String?

    private let stockService = StockService()
    private let positionService = StockPositionService()
    private let profileService = PlayerProfileService()
    private let transactionService = TransactionService()

    init(userID: String? = nil) {
        self.userID = userID
    }

    var canTrade: Bool { userID != nil }

    func position(for symbol: String) -> StockPosition? {
        positions.first { $0.symbol == symbol }
    }

    func loadStocks() {
        isLoading = true
        errorMessage = nil
        stockService.fetchStocks { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let list):
                    self.stocks = list
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

    func openTradeSheet(for stock: Stock) {
        selectedStockForTrade = stock
        tradeQuantityText = ""
        tradeErrorMessage = nil
        tradeSegment = 0
    }

    func closeTradeSheet() {
        selectedStockForTrade = nil
        tradeQuantityText = ""
        tradeErrorMessage = nil
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
            tradeErrorMessage = "Not enough cash. Need \(String(format: "$%.2f", cost)), have \(String(format: "$%.2f", cash))."
            return
        }

        isSubmitting = true
        tradeErrorMessage = nil
        positionService.buyStock(userID: uid, symbol: stock.symbol, shares: shares, pricePerShare: stock.currentPrice) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isSubmitting = false
                switch result {
                case .success:
                    self.recordTransaction(type: "stock_buy", amount: -cost, description: "Bought \(String(format: "%.2f", shares)) \(stock.symbol)")
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
            tradeErrorMessage = "You own \(String(format: "%.2f", owned)) shares. Cannot sell more."
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
                    self.recordTransaction(type: "stock_sell", amount: proceeds, description: "Sold \(String(format: "%.2f", shares)) \(stock.symbol)")
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
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let value = Double(trimmed) else { return 0 }
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
        let absoluteChange = abs(change)
        let sign = change >= 0 ? "+" : "-"
        return "\(sign)$\(String(format: "%.2f", absoluteChange))"
    }
}
