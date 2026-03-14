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
        Group {
            if viewModel.isLoading {
                ProgressView("Loading inventory...")
                    .controlSize(.large)
            } else if let errorMessage = viewModel.errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Failed to load inventory")
                        .font(.headline)

                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
                .padding()
            } else {
                List(viewModel.inventoryItems) { inventoryItem in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(inventoryItem.item.name)
                            .font(.headline)

                        Text("Quantity: \(viewModel.formattedQuantity(for: inventoryItem))")
                            .font(.subheadline)

                        Text("Category: \(inventoryItem.item.category.rawValue)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.insetGrouped)
            }
        }
        .onAppear {
            viewModel.loadInventory()
        }
    }
}

#Preview {
    NavigationStack {
        InventoryView(userID: "demo-user-id-12345")
    }
}
