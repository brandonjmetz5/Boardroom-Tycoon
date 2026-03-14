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
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            Group {
                if viewModel.isLoading {
                    ProgressView("Loading stocks...")
                        .controlSize(.large)
                        .tint(.white)
                        .foregroundStyle(AppTheme.textPrimary)
                } else if let errorMessage = viewModel.errorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Failed to load stocks")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(errorMessage)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(AppTheme.textError)
                    }
                    .padding(AppTheme.horizontalPadding)
                } else if viewModel.stocks.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("No Stocks Yet")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Sector stocks will appear here once they are added to Firestore.")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(AppTheme.cardPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .themedCard()
                    .padding(.horizontal, AppTheme.horizontalPadding)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(viewModel.stocks) { stock in
                                stockCard(stock: stock)
                            }
                        }
                        .padding(.horizontal, AppTheme.horizontalPadding)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Stocks")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
            }
        }
        .onAppear {
            viewModel.loadStocks()
        }
    }

    private func stockCard(stock: Stock) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(stock.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(stock.symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "$%.2f", stock.currentPrice))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .monospacedDigit()
                Text(viewModel.formattedChange(stock.priceChange))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(stock.priceChange >= 0 ? AppTheme.chipPositive : AppTheme.chipNegative)
                    .monospacedDigit()
            }
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }
}

#Preview {
    NavigationStack {
        StocksView()
    }
}
