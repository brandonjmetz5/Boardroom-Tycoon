//
//  InventoryViewModel.swift
//  Boardroom Tycoon
//
//  MVVM: Presentation logic and state for the Inventory screen.
//

import Foundation

@MainActor
final class InventoryViewModel: ObservableObject {
    let userID: String

    @Published private(set) var inventoryItems: [InventoryItem] = []
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?

    private let inventoryService = InventoryService()

    init(userID: String) {
        self.userID = userID
    }

    func loadInventory() {
        inventoryService.fetchInventory(for: userID) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
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

    func formattedQuantity(for inventoryItem: InventoryItem) -> String {
        if inventoryItem.item.isFractional {
            return String(format: "%.2f", inventoryItem.quantity)
        } else {
            return String(Int(inventoryItem.quantity))
        }
    }
}
