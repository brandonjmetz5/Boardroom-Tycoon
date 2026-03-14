//
//  StocksView.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/11/26.
//

import SwiftUI

struct StocksView: View {
    @StateObject private var viewModel = StocksViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading stocks...")
                    .controlSize(.large)
            } else if let errorMessage = viewModel.errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Failed to load stocks")
                        .font(.headline)

                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
                .padding()
            } else if viewModel.stocks.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("No Stocks Yet")
                        .font(.headline)

                    Text("Sector stocks will appear here once they are added to Firestore.")
                        .foregroundStyle(.secondary)
                }
                .padding()
            } else {
                List(viewModel.stocks) { stock in
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

                            Text(viewModel.formattedChange(stock.priceChange))
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
            viewModel.loadStocks()
        }
    }
}

#Preview {
    NavigationStack {
        StocksView()
    }
}
