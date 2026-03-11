//
//  InventoryView.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/11/26.
//

import SwiftUI

struct InventoryView: View {
    let userID: String

    @State private var inventoryItems: [InventoryItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let inventoryService = InventoryService()

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading inventory...")
                    .controlSize(.large)
            } else if let errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Failed to load inventory")
                        .font(.headline)

                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
                .padding()
            } else {
                List(inventoryItems) { inventoryItem in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(inventoryItem.item.name)
                            .font(.headline)

                        Text("Quantity: \(formattedQuantity(for: inventoryItem))")
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
            loadInventory()
        }
    }

    private func loadInventory() {
        inventoryService.fetchInventory(for: userID) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let items):
                    self.inventoryItems = items
                    self.isLoading = false
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func formattedQuantity(for inventoryItem: InventoryItem) -> String {
        if inventoryItem.item.isFractional {
            return String(format: "%.2f", inventoryItem.quantity)
        } else {
            return String(Int(inventoryItem.quantity))
        }
    }
}

#Preview {
    NavigationStack {
        InventoryView(userID: "demo-user-id-12345")
    }
}
