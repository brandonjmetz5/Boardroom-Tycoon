//
//  InventoryViewModel.swift
//  Boardroom Tycoon
//
//  MVVM: Presentation logic and state for the Inventory screen.
//

import Foundation
import Combine

@MainActor
final class InventoryViewModel: ObservableObject {
    let userID: String

    @Published private(set) var inventoryItems: [InventoryItem] = []
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?

    /// Item selected to list on market; sheet shows quantity and price.
    @Published var selectedItemForListing: InventoryItem?
    @Published var listQuantityText = ""
    @Published var listPricePerUnitText = ""
    @Published private(set) var isPostingListing = false
    @Published var listErrorMessage: String?

    private let inventoryService = InventoryService()
    private let marketListingService = MarketListingService()

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

    /// Base resource ID and quality from inventory doc ID (e.g. "raw-gold-q2" -> base "raw-gold", quality 2).
    func resourceBaseIDAndQuality(for inventoryItem: InventoryItem) -> (baseID: String, quality: Int) {
        let docId = inventoryItem.id
        if docId.contains("-q"), let last = docId.split(separator: "q").last, let q = Int(last) {
            let base = docId.replacingOccurrences(of: "-q\(q)", with: "")
            return (base, max(1, q))
        }
        return (docId, 1)
    }

    func openListSheet(for item: InventoryItem) {
        selectedItemForListing = item
        listQuantityText = item.item.isFractional ? String(format: "%.2f", item.quantity) : String(Int(item.quantity))
        listPricePerUnitText = ""
        listErrorMessage = nil
    }

    func closeListSheet() {
        selectedItemForListing = nil
        listQuantityText = ""
        listPricePerUnitText = ""
        listErrorMessage = nil
    }

    func postListing() {
        guard let item = selectedItemForListing else { return }
        let qty = Double(listQuantityText.replacingOccurrences(of: ",", with: "."))
        guard let quantity = qty, quantity > 0 else {
            listErrorMessage = "Enter a valid quantity."
            return
        }
        if quantity > item.quantity {
            listErrorMessage = "You only have \(formattedQuantity(for: item))."
            return
        }
        let price = Double(listPricePerUnitText.replacingOccurrences(of: ",", with: "."))
        guard let pricePerUnit = price, pricePerUnit > 0 else {
            listErrorMessage = "Enter a valid price per unit."
            return
        }
        let (baseID, quality) = resourceBaseIDAndQuality(for: item)
        isPostingListing = true
        listErrorMessage = nil
        marketListingService.createListing(
            sellerUserID: userID,
            sellerName: nil,
            resourceID: baseID,
            resourceName: item.item.name,
            resourceCategory: item.item.category.rawValue,
            quality: quality,
            quantity: quantity,
            pricePerUnit: pricePerUnit,
            isFractional: item.item.isFractional
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isPostingListing = false
                switch result {
                case .success:
                    self.closeListSheet()
                    self.loadInventory()
                case .failure(let error):
                    self.listErrorMessage = error.localizedDescription
                }
            }
        }
    }
}
