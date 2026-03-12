//
//  StocksView.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/11/26.
//

import SwiftUI

struct StocksView: View {
    @State private var stocks: [Stock] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let stockService = StockService()

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading stocks...")
                    .controlSize(.large)
            } else if let errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Failed to load stocks")
                        .font(.headline)

                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
                .padding()
            } else if stocks.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("No Stocks Yet")
                        .font(.headline)

                    Text("Sector stocks will appear here once they are added to Firestore.")
                        .foregroundStyle(.secondary)
                }
                .padding()
            } else {
                List(stocks) { stock in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stock.name)
                                .font(.headline)

                            Text(stock.symbol)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("$\(stock.currentPrice, specifier: "%.2f")")
                                .font(.headline)

                            Text(formattedChange(stock.priceChange))
                                .font(.caption)
                                .foregroundStyle(stock.priceChange >= 0 ? .green : .red)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.insetGrouped)
            }
        }
        .onAppear {
            loadStocks()
        }
    }

    private func loadStocks() {
        stockService.fetchStocks { result in
            DispatchQueue.main.async {
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

    private func formattedChange(_ change: Double) -> String {
        let absoluteChange = abs(change)
        let sign = change >= 0 ? "+" : "-"
        return "\(sign)$\(String(format: "%.2f", absoluteChange))"
    }
}

#Preview {
    NavigationStack {
        StocksView()
    }
}
