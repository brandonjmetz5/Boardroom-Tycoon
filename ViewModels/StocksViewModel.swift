//
//  StocksViewModel.swift
//  Boardroom Tycoon
//
//  MVVM: Presentation logic and state for the Stocks screen.
//

import Foundation

@MainActor
final class StocksViewModel: ObservableObject {
    @Published private(set) var stocks: [Stock] = []
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?

    private let stockService = StockService()

    func loadStocks() {
        stockService.fetchStocks { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let loadedStocks):
                    self.stocks = loadedStocks
                    self.isLoading = false
                    self.errorMessage = nil
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    func formattedChange(_ change: Double) -> String {
        let absoluteChange = abs(change)
        let sign = change >= 0 ? "+" : "-"
        return "\(sign)$\(String(format: "%.2f", absoluteChange))"
    }
}
