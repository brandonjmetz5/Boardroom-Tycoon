//
//  InventoryView.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/11/26.
//

import SwiftUI

struct InventoryView: View {
    let userID: String

    @StateObject private var viewModel: InventoryViewModel

    init(userID: String) {
        self.userID = userID
        _viewModel = StateObject(wrappedValue: InventoryViewModel(userID: userID))
    }

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            Group {
                if viewModel.isLoading {
                    ProgressView("Loading inventory...")
                        .controlSize(.large)
                        .tint(.white)
                        .foregroundStyle(AppTheme.textPrimary)
                } else if let errorMessage = viewModel.errorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Failed to load inventory")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(errorMessage)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(AppTheme.textError)
                    }
                    .padding(AppTheme.horizontalPadding)
                } else if viewModel.inventoryItems.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("No Items")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Your inventory will show here once you have items.")
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
                            ForEach(viewModel.inventoryItems) { inventoryItem in
                                inventoryItemCard(inventoryItem: inventoryItem)
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
                Text("Inventory")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
            }
        }
        .onAppear {
            viewModel.loadInventory()
        }
        .sheet(item: $viewModel.selectedItemForListing) { item in
            listOnMarketSheet(item: item)
        }
    }

    private func inventoryItemCard(inventoryItem: InventoryItem) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(inventoryItem.item.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Quantity: \(viewModel.formattedQuantity(for: inventoryItem))")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)

                Text(inventoryItem.item.category.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textTertiary)
            }

            Spacer()

            Text(viewModel.formattedQuantity(for: inventoryItem))
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .monospacedDigit()

            Button("List") {
                viewModel.openListSheet(for: inventoryItem)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppTheme.chipReady)
            .clipShape(Capsule())
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    private func listOnMarketSheet(item: InventoryItem) -> some View {
        let (_, quality) = viewModel.resourceBaseIDAndQuality(for: item)
        return NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    if let err = viewModel.listErrorMessage {
                        Text(err)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.textError)
                    }
                    Text(item.item.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Q\(quality) · You have \(viewModel.formattedQuantity(for: item))")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("Quantity to list")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    TextField("Quantity", text: $viewModel.listQuantityText)
                        .keyboardType(item.item.isFractional ? .decimalPad : .numberPad)
                        .textFieldStyle(.roundedBorder)
                    Text("Price per unit ($)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    TextField("Price per unit", text: $viewModel.listPricePerUnitText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(AppTheme.cardPadding)
            }
            .navigationTitle("List on Market")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.cardBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        viewModel.closeListSheet()
                    }
                    .foregroundStyle(AppTheme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Post") {
                        viewModel.postListing()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.chipReady)
                    .disabled(viewModel.isPostingListing)
                }
            }
            .overlay {
                if viewModel.isPostingListing {
                    ProgressView("Posting...")
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        InventoryView(userID: "demo-user-id-12345")
    }
}
