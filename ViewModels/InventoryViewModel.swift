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

    struct QualityGroup: Identifiable {
        let id: String
        let quality: Int
        let quantity: Double
    }

    struct ResourceGroup: Identifiable {
        let id: String
        let category: ItemCategory
        let baseID: String
        let item: Item
        let totalQuantity: Double
        let qualities: [QualityGroup]
    }

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
            return NumberFormatting.decimal(inventoryItem.quantity, fractionDigits: 2)
        } else {
            return NumberFormatting.integer(Int(inventoryItem.quantity))
        }
    }

    func formattedTotalQuantity() -> String {
        // Inventory quantities can mix fractional + whole items; show a friendly overall number.
        // If *any* fractional exists, show decimals; otherwise show integers.
        let hasFractional = inventoryItems.contains(where: { $0.item.isFractional })
        return formattedTotalQuantity(value: totalInventoryQuantity, isFractional: hasFractional)
    }

    func formattedTotalQuantity(value: Double, isFractional: Bool) -> String {
        if isFractional {
            return NumberFormatting.decimal(value, fractionDigits: 2)
        } else {
            return NumberFormatting.integer(Int(value))
        }
    }

    // MARK: - Insight stats

    var totalInventoryValue: Double {
        inventoryItems.reduce(0) { acc, inv in
            (ItemValueCatalog.value(quantity: inv.quantity, itemId: inv.item.id) ?? 0) + acc
        }
    }

    var totalInventoryQuantity: Double {
        inventoryItems.reduce(0) { $0 + $1.quantity }
    }

    var distinctResourceCount: Int {
        let set = Set(inventoryItems.map { resourceBaseIDAndQuality(for: $0).baseID })
        return set.count
    }

    var highestQualityAvailable: Int {
        let qualities = inventoryItems.map { resourceBaseIDAndQuality(for: $0).quality }
        return qualities.max() ?? 1
    }

    var totalQualityStacks: Int {
        let set = Set(inventoryItems.map { item in
            let parsed = resourceBaseIDAndQuality(for: item)
            return "\(parsed.baseID)-q\(parsed.quality)"
        })
        return set.count
    }

    // MARK: - Grouping

    var resourceGroupsByCategory: [(category: ItemCategory, resources: [ResourceGroup])] {
        struct TempResource {
            var item: Item
            var totalQuantity: Double = 0
            var qualities: [Int: Double] = [:] // quality -> total quantity
        }

        var dict: [String: TempResource] = [:] // key: "\(category.rawValue)|\(baseID)"
        var meta: [String: (category: ItemCategory, baseID: String)] = [:]

        for inv in inventoryItems {
            let parsed = resourceBaseIDAndQuality(for: inv)
            let category = inv.item.category
            let baseID = parsed.baseID
            let quality = parsed.quality
            let key = "\(category.rawValue)|\(baseID)"

            if dict[key] == nil {
                meta[key] = (category: category, baseID: baseID)
                dict[key] = TempResource(item: inv.item)
            }

            dict[key]!.totalQuantity += inv.quantity
            dict[key]!.qualities[quality, default: 0] += inv.quantity
        }

        // Build category sections; hide empty categories.
        var out: [(category: ItemCategory, resources: [ResourceGroup])] = []

        for category in ItemCategory.allCases {
            let resourcesForCat: [ResourceGroup] = dict.compactMap { entry in
                let (cat, baseID) = meta[entry.key] ?? (category: category, baseID: "")
                guard cat == category, !baseID.isEmpty else { return nil }
                let temp = entry.value

                let qualities = temp.qualities
                    .map { q, qty in
                        QualityGroup(id: "\(baseID)-q\(q)", quality: q, quantity: qty)
                    }
                    .sorted { $0.quality > $1.quality } // highest quality first

                let id = "\(category.rawValue)|\(baseID)"
                return ResourceGroup(
                    id: id,
                    category: category,
                    baseID: baseID,
                    item: temp.item,
                    totalQuantity: temp.totalQuantity,
                    qualities: qualities
                )
            }
            .sorted { a, b in
                // Prefer value-based sorting for better UX.
                let av = ItemValueCatalog.value(quantity: a.totalQuantity, itemId: a.item.id) ?? 0
                let bv = ItemValueCatalog.value(quantity: b.totalQuantity, itemId: b.item.id) ?? 0
                if av != bv { return av > bv }
                return a.item.name < b.item.name
            }

            if !resourcesForCat.isEmpty {
                out.append((category: category, resources: resourcesForCat))
            }
        }

        return out
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
        listQuantityText = item.item.isFractional
            ? NumberFormatting.decimal(item.quantity, fractionDigits: 2)
            : NumberFormatting.integer(Int(item.quantity))
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
        let quantity = NumberFormatting.parseDecimalInput(listQuantityText)
        guard let quantity, quantity > 0 else {
            listErrorMessage = "Enter a valid quantity."
            return
        }
        if quantity > item.quantity {
            listErrorMessage = "You only have \(formattedQuantity(for: item))."
            return
        }
        let pricePerUnit = NumberFormatting.parseDecimalInput(listPricePerUnitText)
        guard let pricePerUnit, pricePerUnit > 0 else {
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
