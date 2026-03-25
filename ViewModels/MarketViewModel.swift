//
//  MarketViewModel.swift
//  Boardroom Tycoon
//
//  MVVM: Presentation logic and state for the Market screen.
//

import SwiftUI
import Foundation
import Combine

@MainActor
final class MarketViewModel: ObservableObject {
    let userID: String

    /// 0 = Building Auctions, 1 = Buy Orders, 2 = Resource Listings
    @Published var marketSegment = 0

    @Published private(set) var mineListings: [MineMarketListing] = []
    @Published private(set) var isLoading = true
    @Published private(set) var loadingErrorMessage: String?
    @Published var actionErrorMessage: String?

    @Published var selectedListingForBid: MineMarketListing?
    @Published var bidAmountText = ""
    @Published private(set) var isSubmitting = false

    // MARK: - Buy Orders
    @Published private(set) var buyOrders: [BuyOrder] = []
    @Published private(set) var buyOrdersLoading = false
    @Published private(set) var buyOrdersErrorMessage: String?
    @Published var buyOrderActionMessage: String?
    @Published var filterCategory: String?
    @Published var filterResourceID: String?
    @Published var filterQuality: Int?
    @Published private(set) var inventoryItems: [InventoryItem] = []
    @Published private(set) var profile: PlayerProfile?
    @Published var selectedOrderForFulfillConfirm: BuyOrder?
    @Published var showNewBuyOrderSheet = false
    /// One row per resource line; each has optional item, quality, quantity text.
    @Published var newOrderLines: [NewOrderLine] = []
    @Published var newOrderTotalPriceText = ""
    @Published var newOrderPosting = false
    @Published var newOrderErrorMessage: String?

    // MARK: - Resource Listings (buy individual resources)
    @Published var filterResourceListingsID: String?
    @Published var minQualityForListings = 0
    @Published private(set) var allResourceListings: [MarketListing] = []
    @Published private(set) var resourceListingsLoading = false
    @Published private(set) var resourceListingsErrorMessage: String?
    @Published var selectedListingToBuy: MarketListing?
    @Published private(set) var buyListingInProgress = false
    @Published var buyListingErrorMessage: String?

    // MARK: - Aggregates / deal indicators

    @Published private(set) var aggregates: [String: MarketAggregate] = [:] // key: resourceID-qQuality
    @Published private(set) var aggregatesLoaded = false
    @Published private(set) var aggregatesErrorMessage: String?

    private let mineMarketService = MineMarketService()
    private let buyOrderService = BuyOrderService()
    private let marketListingService = MarketListingService()
    private let playerProfileService = PlayerProfileService()
    private let inventoryService = InventoryService()
    private let analyticsService = MarketAnalyticsService()

    init(userID: String) {
        self.userID = userID
    }

    private func aggregateKey(resourceID: String, quality: Int) -> String {
        "\(resourceID)-q\(max(1, quality))"
    }

    func loadAggregatesIfNeeded() {
        if aggregatesLoaded { return }
        analyticsService.fetchAggregates { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let list):
                    var dict: [String: MarketAggregate] = [:]
                    for agg in list {
                        let key = self.aggregateKey(resourceID: agg.resourceID, quality: agg.quality)
                        dict[key] = agg
                    }
                    self.aggregates = dict
                    self.aggregatesLoaded = true
                    self.aggregatesErrorMessage = nil
                case .failure(let error):
                    self.aggregatesErrorMessage = error.localizedDescription
                    self.aggregatesLoaded = true
                }
            }
        }
    }

    func dealDeltaForListing(_ listing: MarketListing) -> Double? {
        guard let avg = averageListingPrice(resourceID: listing.item.id, quality: listing.quality), avg > 0 else { return nil }
        return (listing.pricePerUnit - avg) / avg * 100.0
    }

    func dealDeltaForBuyOrder(_ order: BuyOrder) -> Double? {
        // Compare netToSeller against blended fair value of selling each line individually at avgListingPrice.
        var fairValue: Double = 0
        for line in order.lines {
            guard let avg = averageListingPrice(resourceID: line.resourceID, quality: line.resourceQuality), avg > 0 else { continue }
            fairValue += avg * line.quantity
        }
        guard fairValue > 0 else { return nil }
        let actual = order.netToSeller
        let delta = (actual - fairValue) / fairValue * 100.0
        return delta
    }

    private func averageListingPrice(resourceID: String, quality: Int) -> Double? {
        // Prefer server-aggregated average if available.
        let key = aggregateKey(resourceID: resourceID, quality: quality)
        if let agg = aggregates[key], let avg = agg.avgListingPrice, avg > 0 {
            return avg
        }

        // Fallback: compute a volume-weighted average from currently loaded listings.
        let bucket = allResourceListings.filter { $0.item.id == resourceID && $0.quality == max(1, quality) }
        if bucket.isEmpty { return nil }
        let qtySum = bucket.reduce(0.0) { $0 + $1.quantity }
        if qtySum <= 0 { return nil }
        let valueSum = bucket.reduce(0.0) { $0 + ($1.pricePerUnit * $1.quantity) }
        let avg = valueSum / qtySum
        return avg > 0 ? avg : nil
    }

    func loadListings() {
        isLoading = true
        loadingErrorMessage = nil

        mineMarketService.fetchActiveMineListings { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let listings):
                    self.mineListings = listings
                    self.isLoading = false
                case .failure(let error):
                    self.loadingErrorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    func buyNow(_ listing: MineMarketListing) {
        isSubmitting = true
        actionErrorMessage = nil

        mineMarketService.buyNowMineListing(for: userID, listing: listing) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isSubmitting = false
                switch result {
                case .success:
                    self.loadListings()
                case .failure(let error):
                    self.actionErrorMessage = error.localizedDescription
                }
            }
        }
    }

    func submitBid(_ listing: MineMarketListing) {
        guard let bidAmount = Double(bidAmountText), bidAmount > 0 else {
            actionErrorMessage = "Enter a valid bid amount."
            return
        }

        isSubmitting = true
        actionErrorMessage = nil

        mineMarketService.placeBid(for: userID, listing: listing, bidAmount: bidAmount) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isSubmitting = false
                switch result {
                case .success:
                    self.selectedListingForBid = nil
                    self.bidAmountText = ""
                    self.loadListings()
                case .failure(let error):
                    self.actionErrorMessage = error.localizedDescription
                }
            }
        }
    }

    func cancelListing(_ listing: MineMarketListing) {
        isSubmitting = true
        actionErrorMessage = nil

        mineMarketService.cancelMineListing(for: userID, listing: listing) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isSubmitting = false
                switch result {
                case .success:
                    self.loadListings()
                case .failure(let error):
                    self.actionErrorMessage = error.localizedDescription
                }
            }
        }
    }

    func openBidSheet(for listing: MineMarketListing) {
        actionErrorMessage = nil
        bidAmountText = ""
        selectedListingForBid = listing
    }

    func closeBidSheet() {
        selectedListingForBid = nil
        bidAmountText = ""
        actionErrorMessage = nil
    }

    func formattedTimeRemaining(until endDate: Date, now: Date) -> String {
        let remainingSeconds = max(0, Int(ceil(endDate.timeIntervalSince(now))))
        let hours = remainingSeconds / 3600
        let minutes = (remainingSeconds % 3600) / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    func mineLabel(for resourceType: ResourceType) -> String {
        switch resourceType {
        case .gold: return "Gold Mine"
        case .silver: return "Silver Mine"
        case .diamond: return "Diamond Mine"
        case .oil: return "Oil Rig"
        case .coal: return "Coal Mine"
        case .iron: return "Iron Mine"
        case .quarry, .stoneQuarry: return "Stone Quarry"
        case .sandQuarry: return "Sand Quarry"
        case .gravelQuarry: return "Gravel Quarry"
        default: return resourceType.rawValue
        }
    }

    // MARK: - Buy Orders

    func loadBuyOrders() {
        buyOrdersLoading = true
        buyOrdersErrorMessage = nil
        let group = DispatchGroup()
        var ordersResult: Result<[BuyOrder], Error>?
        var profileResult: Result<PlayerProfile, Error>?
        var inventoryResult: Result<[InventoryItem], Error>?

        group.enter()
        buyOrderService.fetchOpenBuyOrders(resourceCategory: filterCategory, resourceID: filterResourceID, resourceQuality: filterQuality) { result in
            ordersResult = result
            group.leave()
        }
        group.enter()
        playerProfileService.fetchPlayerProfile(for: userID) { result in
            profileResult = result
            group.leave()
        }
        group.enter()
        inventoryService.fetchInventory(for: userID) { result in
            inventoryResult = result
            group.leave()
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            if let r = ordersResult, case .success(let list) = r { self.buyOrders = list }
            else if let r = ordersResult, case .failure(let e) = r { self.buyOrdersErrorMessage = e.localizedDescription }
            if let r = profileResult, case .success(let p) = r { self.profile = p }
            if let r = inventoryResult, case .success(let list) = r { self.inventoryItems = list }
            self.buyOrdersLoading = false
        }
    }

    func inventoryQuantity(for docID: String) -> Double {
        inventoryItems.first(where: { $0.id == docID })?.quantity ?? 0
    }

    func canFulfill(_ order: BuyOrder) -> Bool {
        for line in order.lines {
            if inventoryQuantity(for: line.resourceInventoryDocID) < line.quantity { return false }
        }
        return true
    }

    func addNewOrderLine() {
        newOrderLines.append(NewOrderLine())
    }

    func removeNewOrderLine(at indexSet: IndexSet) {
        newOrderLines.remove(atOffsets: indexSet)
    }

    func setNewOrderLineItem(index: Int, item: Item?) {
        guard index >= 0, index < newOrderLines.count else { return }
        var updated = newOrderLines
        updated[index].item = item
        newOrderLines = updated
    }

    func setNewOrderLineQuality(index: Int, quality: Int) {
        guard index >= 0, index < newOrderLines.count else { return }
        var updated = newOrderLines
        updated[index].quality = quality
        newOrderLines = updated
    }

    func setNewOrderLineQuantity(index: Int, text: String) {
        guard index >= 0, index < newOrderLines.count else { return }
        var updated = newOrderLines
        updated[index].quantityText = text
        newOrderLines = updated
    }

    func postBuyOrder() {
        let builtLines: [BuyOrderLine] = newOrderLines.compactMap { row in
            guard let item = row.item, let qty = Double(row.quantityText), qty > 0 else { return nil }
            return BuyOrderLine(
                resourceID: item.id,
                resourceName: item.name,
                resourceCategory: item.category.rawValue,
                resourceQuality: max(1, row.quality),
                quantity: qty,
                isFractional: item.isFractional
            )
        }
        guard !builtLines.isEmpty else {
            newOrderErrorMessage = "Add at least one resource with a valid quantity."
            return
        }
        guard let total = Double(newOrderTotalPriceText), total > 0 else {
            newOrderErrorMessage = "Enter a valid total price."
            return
        }
        if (profile?.cash ?? 0) < total {
            newOrderErrorMessage = "Not enough cash. You need \(Int(total)) but have \(Int(profile?.cash ?? 0))."
            return
        }

        newOrderPosting = true
        newOrderErrorMessage = nil
        buyOrderService.postBuyOrder(
            buyerUserID: userID,
            buyerName: nil,
            lines: builtLines,
            totalPrice: total
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.newOrderPosting = false
                switch result {
                case .success:
                    self.showNewBuyOrderSheet = false
                    self.newOrderLines = []
                    self.newOrderTotalPriceText = ""
                    self.loadBuyOrders()
                case .failure(let error):
                    self.newOrderErrorMessage = error.localizedDescription
                }
            }
        }
    }

    func cancelBuyOrder(_ order: BuyOrder) {
        guard order.buyerUserID == userID else { return }
        isSubmitting = true
        buyOrderActionMessage = nil
        buyOrderService.cancelBuyOrder(orderID: order.id, buyerUserID: userID) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isSubmitting = false
                switch result {
                case .success:
                    self.loadBuyOrders()
                case .failure(let error):
                    self.buyOrderActionMessage = error.localizedDescription
                }
            }
        }
    }

    func fulfillBuyOrder(_ order: BuyOrder) {
        selectedOrderForFulfillConfirm = nil
        isSubmitting = true
        buyOrderActionMessage = nil
        buyOrderService.fulfillBuyOrder(orderID: order.id, sellerUserID: userID) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isSubmitting = false
                switch result {
                case .success:
                    self.loadBuyOrders()
                    self.buyOrderActionMessage = "Order fulfilled. You received \(NumberFormatting.currency(order.netToSeller, fractionDigits: 2))."
                case .failure(let error):
                    self.buyOrderActionMessage = error.localizedDescription
                }
            }
        }
    }

    func confirmFulfillTapped(_ order: BuyOrder) {
        selectedOrderForFulfillConfirm = order
    }

    func closeFulfillConfirm() {
        selectedOrderForFulfillConfirm = nil
    }

    var tradeableItemsByCategory: [ItemCategory: [Item]] {
        ItemCategory.allCases.reduce(into: [:]) { acc, cat in
            acc[cat] = MarketCatalog.tradeableItems(byCategory: cat)
        }
    }

    var feePercent: Double { MarketCatalog.buyOrderFeePercent }
    func feeAmount(for totalPrice: Double) -> Double { totalPrice * (feePercent / 100) }
    func netToSeller(for totalPrice: Double) -> Double { totalPrice - feeAmount(for: totalPrice) }

    // MARK: - Resource Listings

    func loadResourceListings() {
        resourceListingsLoading = true
        resourceListingsErrorMessage = nil
        marketListingService.fetchAllListings { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.resourceListingsLoading = false
                switch result {
                case .success(let list):
                    self.allResourceListings = list
                case .failure(let error):
                    self.resourceListingsErrorMessage = error.localizedDescription
                    self.allResourceListings = []
                }
            }
        }
    }

    /// Filtered and sorted resource listings (cheapest first).
    var resourceListings: [MarketListing] {
        var list = allResourceListings
        if let rid = filterResourceListingsID, !rid.isEmpty {
            list = list.filter { $0.item.id == rid }
        }
        if minQualityForListings > 0 {
            list = list.filter { $0.quality >= minQualityForListings }
        }
        return list.sorted { $0.pricePerUnit < $1.pricePerUnit }
    }

    func openBuyListingSheet(_ listing: MarketListing) {
        buyListingErrorMessage = nil
        selectedListingToBuy = listing
    }

    func closeBuyListingSheet() {
        selectedListingToBuy = nil
        buyListingErrorMessage = nil
    }

    func confirmBuyFromListing() {
        guard let listing = selectedListingToBuy else { return }
        buyListingInProgress = true
        buyListingErrorMessage = nil
        marketListingService.buyFromListing(for: userID, listing: listing) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.buyListingInProgress = false
                switch result {
                case .success:
                    self.closeBuyListingSheet()
                    self.loadResourceListings() // refresh list after buy
                case .failure(let error):
                    self.buyListingErrorMessage = error.localizedDescription
                }
            }
        }
    }

    func cancelMyListing(_ listing: MarketListing) {
        guard listing.sellerUserID == userID else { return }
        isSubmitting = true
        marketListingService.cancelListing(listingID: listing.id, sellerUserID: userID) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isSubmitting = false
                switch result {
                case .success:
                    self.loadResourceListings()
                case .failure(let error):
                    self.buyOrderActionMessage = error.localizedDescription
                }
            }
        }
    }
}

/// One line in the new-buy-order form: resource picker, quality, quantity.
struct NewOrderLine: Identifiable {
    let id = UUID()
    var item: Item?
    var quality: Int = 1
    var quantityText: String = ""
}
