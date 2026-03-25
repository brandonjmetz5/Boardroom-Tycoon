//
//  BuildingDetailViewModel.swift
//  Boardroom Tycoon
//
//  MVVM: Presentation logic and state for the Building Detail screen.
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class BuildingDetailViewModel: ObservableObject {
    let userID: String

    @Published private(set) var currentBuilding: Building
    @Published private(set) var currentListing: MineMarketListing?
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?
    /// All recipes for this building (one for refineries, three for Fabrication Plant, etc.).
    @Published private(set) var recipes: [Recipe] = []
    /// Single recipe when building has only one (convenience for UI).
    var recipe: Recipe? { recipes.first }
    /// For multi-recipe buildings, the recipe selected for production.
    @Published var selectedRecipeForBuilding: Recipe?

    @Published private(set) var inventoryItems: [InventoryItem] = []
    /// Max quality unlocked for the primary output resource or recipe output (if any).
    @Published private(set) var maxOutputQuality: Int = 1
    /// Quality the player wants to produce for recipe-based buildings.
    @Published var selectedOutputQuality: Int = 1

    @Published var showListingSheet = false
    @Published var buyNowPriceText = ""
    @Published private(set) var isBuyingMissing = false
    @Published var buyMissingErrorMessage: String?
    @Published private(set) var isGeneratingBuyMissingConfirmation = false

    @Published var showBuyMissingConfirmationSheet = false
    @Published var buyMissingConfirmationTitle: String = ""
    @Published private(set) var buyMissingConfirmationOptions: [BuyMissingPlan] = []
    @Published var selectedBuyMissingConfirmationOptionIndex: Int = 0

    private let productionService = ProductionService()
    private let buildingService = BuildingService()
    private let mineMarketService = MineMarketService()
    private let recipeService = RecipeService()
    private let inventoryService = InventoryService()
    private let resourceQualityService = ResourceQualityService()
    private let marketListingService = MarketListingService()

    var onDismiss: (() -> Void)?

    init(userID: String, building: Building) {
        self.userID = userID
        self.currentBuilding = building
    }

    // MARK: - Actions

    func refreshBuilding() {
        buildingService.fetchBuildings(for: userID) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let buildings):
                    if let updated = buildings.first(where: { $0.id == self.currentBuilding.id }) {
                        self.currentBuilding = updated
                        self.refreshListingIfNeeded()
                        self.loadRecipesIfNeeded()
                        self.loadInventory()
                    }
                case .failure:
                    break
                }
            }
        }
    }

    private func loadRecipesIfNeeded() {
        var list = RecipeCatalog.recipes(forBuildingName: currentBuilding.name)
        if list.isEmpty { list = RecipeCatalog.recipes(forBuildingId: currentBuilding.id) }
        recipes = list
        if selectedRecipeForBuilding == nil, let first = list.first {
            selectedRecipeForBuilding = first
        }
        loadQualityForCurrentOutput()
    }

    private func loadInventory() {
        inventoryService.fetchInventory(for: userID) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                if case .success(let items) = result { self.inventoryItems = items }
            }
        }
    }

    private func loadQualityForCurrentOutput() {
        let outputItemId: String?
        if isExtractor {
            // Extractors output raw resources (e.g. raw-gold); map ResourceType to base item id.
            if let rt = currentBuilding.resourceType {
                switch rt {
                case .gold: outputItemId = "raw-gold"
                case .silver: outputItemId = "raw-silver"
                case .diamond: outputItemId = "raw-diamonds"
                case .oil: outputItemId = "crude-oil"
                case .coal: outputItemId = "raw-coal"
                case .iron: outputItemId = "raw-iron"
                case .quarry, .stoneQuarry: outputItemId = "raw-stone"
                case .sandQuarry: outputItemId = "raw-sand"
                case .gravelQuarry: outputItemId = "raw-gravel"
                }
            } else {
                outputItemId = nil
            }
        } else {
            outputItemId = (selectedRecipeForBuilding ?? recipe)?.outputItems.first?.item.id
        }

        guard let id = outputItemId else {
            maxOutputQuality = 1
            selectedOutputQuality = 1
            return
        }

        resourceQualityService.fetchQualities(for: userID) { [weak self] (result: Result<[ResourceQuality], Error>) in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let qualities):
                    let q = qualities.first(where: { $0.id == id })?.qualityLevel ?? 1
                    self.maxOutputQuality = max(1, q)
                    if self.selectedOutputQuality > self.maxOutputQuality {
                        self.selectedOutputQuality = self.maxOutputQuality
                    }
                case .failure:
                    self.maxOutputQuality = 1
                    self.selectedOutputQuality = 1
                }
            }
        }
    }

    private func refreshListingIfNeeded() {
        guard currentBuilding.isListedOnMarket == true,
              let listingID = currentBuilding.marketListingID,
              !listingID.isEmpty
        else {
            currentListing = nil
            return
        }

        mineMarketService.fetchMineListing(by: listingID) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let listing):
                    self.currentListing = listing
                case .failure:
                    self.currentListing = nil
                }
            }
        }
    }

    /// Start production (building-level; throughput scaled by building level).
    func startProduction() {
        guard canStartProduction else { return }
        isWorking = true
        errorMessage = nil
        if isExtractor {
            let targetQuality = max(1, min(maxOutputQuality, selectedOutputQuality))
            productionService.startProduction(for: userID, buildingID: currentBuilding.id, targetQuality: targetQuality) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.isWorking = false
                    switch result {
                    case .success: self.refreshBuilding()
                    case .failure(let error): self.errorMessage = error.localizedDescription
                    }
                }
            }
        } else {
            guard let r = selectedRecipeForBuilding ?? recipe else {
                isWorking = false
                errorMessage = "No recipe selected."
                return
            }
            let targetQuality = max(1, min(maxOutputQuality, selectedOutputQuality))
            productionService.startRecipeProduction(for: userID, building: currentBuilding, recipe: r, targetQuality: targetQuality) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.isWorking = false
                    switch result {
                    case .success: self.refreshBuilding()
                    case .failure(let error): self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    /// Collect production (building-level).
    func collectProduction() {
        guard isReadyToCollect(at: Date()) else { return }
        isWorking = true
        errorMessage = nil
        productionService.collectProduction(for: userID, buildingID: currentBuilding.id) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isWorking = false
                switch result {
                case .success: self.refreshBuilding()
                case .failure(let error): self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func sellToSystem() {
        isWorking = true
        errorMessage = nil

        buildingService.sellBuildingToSystem(
            for: userID,
            building: currentBuilding,
            sellValue: scrapValue()
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isWorking = false
                switch result {
                case .success:
                    self.onDismiss?()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func listOwnedMine() {
        guard let buyNowPrice = Double(buyNowPriceText), buyNowPrice > 0 else {
            errorMessage = "Enter a valid buy now price."
            return
        }

        isWorking = true
        errorMessage = nil

        mineMarketService.listOwnedMineOnMarket(
            for: userID,
            building: currentBuilding,
            buyNowPrice: buyNowPrice
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isWorking = false
                switch result {
                case .success:
                    self.showListingSheet = false
                    self.buyNowPriceText = ""
                    self.onDismiss?()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func cancelListing() {
        guard let currentListing else { return }

        isWorking = true
        errorMessage = nil

        mineMarketService.cancelMineListing(for: userID, listing: currentListing) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isWorking = false
                switch result {
                case .success:
                    self.onDismiss?()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func openListingSheet() {
        errorMessage = nil
        buyNowPriceText = ""
        showListingSheet = true
    }

    func closeListingSheet() {
        showListingSheet = false
        buyNowPriceText = ""
        errorMessage = nil
    }

    func upgradeBuildingLevel() {
        isWorking = true
        errorMessage = nil
        buildingService.upgradeBuildingLevel(for: userID, buildingID: currentBuilding.id) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isWorking = false
                switch result {
                case .success: self.refreshBuilding()
                case .failure(let error): self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func seedInventoryForTesting() {
        isWorking = true
        errorMessage = nil
        inventoryService.seedInventoryForTesting(for: userID, quantityPerItem: 5) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isWorking = false
                switch result {
                case .success:
                    self.errorMessage = "Seeded 5 of every resource into inventory."
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Display helpers

    var canUpgradeBuilding: Bool {
        currentBuilding.level < BuildingService.maxBuildingLevel && (currentBuilding.isListedOnMarket ?? false) == false
    }

    /// Cash cost to upgrade to next level (base * cost multiplier for target level).
    var upgradeCashCost: Double {
        let targetLevel = currentBuilding.level + 1
        return (BuildingService.baseUpgradeCashCost * BuildingLevelCatalog.upgradeCostMultiplier(forTargetLevel: targetLevel)).rounded()
    }

    func isReadyToCollect(at date: Date) -> Bool {
        guard let productionEndsAt = currentBuilding.productionEndsAt else { return false }
        return currentBuilding.isProducing == true && productionEndsAt <= date
    }

    /// Can start production (building not listed, not producing, enough scaled inputs).
    var canStartProduction: Bool {
        guard (currentBuilding.isListedOnMarket ?? false) == false, currentBuilding.isProducing != true else { return false }
        if isExtractor {
            let mult = BuildingLevelCatalog.throughputMultiplier(forLevel: currentBuilding.level)
            let fuelNeed = BuildingLevelCatalog.scaleQuantity(ProductionService.baseFuelPerExtractorCycle, throughputMultiplier: mult)
            let fuelDocId = ProductionService.fuelDocID(quality: selectedOutputQuality)
            return inventoryQuantity(for: fuelDocId) >= fuelNeed
        }
        guard let r = selectedRecipeForBuilding ?? recipe else { return false }
        let mult = BuildingLevelCatalog.throughputMultiplier(forLevel: currentBuilding.level)
        let targetQ = max(1, min(maxOutputQuality, selectedOutputQuality))
        for input in r.inputItems {
            let need = input.item.isFractional
                ? BuildingLevelCatalog.scaleQuantityFractional(input.quantity, throughputMultiplier: mult)
                : BuildingLevelCatalog.scaleQuantity(input.quantity, throughputMultiplier: mult)
            let requiredDocId = targetQ > 1 ? "\(input.item.id)-q\(targetQ)" : input.item.id
            if inventoryQuantity(for: requiredDocId) < need { return false }
        }
        return true
    }

    func inventoryQuantity(for itemId: String) -> Double {
        // `itemId` may be either the inventory documentID (with "-qX" suffix) or the stored `item.id`.
        inventoryItems.first(where: { $0.id == itemId || $0.item.id == itemId })?.quantity ?? 0
    }

    /// Scaled input items for display (name, itemId, needed quantity).
    func scaledInputsForDisplay() -> [(name: String, itemId: String, needed: Double)] {
        if isExtractor {
            let mult = BuildingLevelCatalog.throughputMultiplier(forLevel: currentBuilding.level)
            let n = BuildingLevelCatalog.scaleQuantity(ProductionService.baseFuelPerExtractorCycle, throughputMultiplier: mult)
            let fuelDocId = ProductionService.fuelDocID(quality: selectedOutputQuality)
            let fuelName = selectedOutputQuality > 1 ? "Fuel Cells (Q\(selectedOutputQuality))" : "Fuel Cells"
            return [(fuelName, fuelDocId, n)]
        }
        guard let r = selectedRecipeForBuilding ?? recipe else { return [] }
        let mult = BuildingLevelCatalog.throughputMultiplier(forLevel: currentBuilding.level)
        let targetQ = max(1, min(maxOutputQuality, selectedOutputQuality))
        return r.inputItems.map { ing in
            let requiredDocId = targetQ > 1 ? "\(ing.item.id)-q\(targetQ)" : ing.item.id
            let qty = ing.item.isFractional
                ? BuildingLevelCatalog.scaleQuantityFractional(ing.quantity, throughputMultiplier: mult)
                : BuildingLevelCatalog.scaleQuantity(ing.quantity, throughputMultiplier: mult)
            return (ing.item.name, requiredDocId, qty)
        }
    }

    struct ScaledInputLine: Identifiable {
        let id: String
        let name: String
        let baseItemId: String
        let requiredDocId: String
        let quality: Int
        let neededQty: Double
        let haveQty: Double
        let missingQty: Double
    }

    // MARK: - Buy-missing purchase planning

    struct BuyTask {
        let listing: MarketListing
        let quantityToBuy: Double
    }

    struct BuyMissingPlan: Identifiable {
        let id = UUID().uuidString
        let title: String
        let tasks: [BuyTask]
        let subtotal: Double
        let fee: Double
        let sellerReceives: Double
    }

    private struct MissingInputLine {
        let name: String
        let baseItemId: String
        let quality: Int
        let missingQty: Double
    }

    /// Scaled input lines for an arbitrary recipe at the current building level and selectedOutputQuality.
    func scaledInputs(for recipe: Recipe) -> [ScaledInputLine] {
        let mult = BuildingLevelCatalog.throughputMultiplier(forLevel: currentBuilding.level)
        let targetQ = max(1, min(maxOutputQuality, selectedOutputQuality))

        return recipe.inputItems.map { ing in
            let needed = ing.item.isFractional
                ? BuildingLevelCatalog.scaleQuantityFractional(ing.quantity, throughputMultiplier: mult)
                : BuildingLevelCatalog.scaleQuantity(ing.quantity, throughputMultiplier: mult)

            let requiredDocId = targetQ > 1 ? "\(ing.item.id)-q\(targetQ)" : ing.item.id
            let have = inventoryQuantity(for: requiredDocId)
            let missing = max(0, needed - have)

            return ScaledInputLine(
                id: "\(ing.item.id)-q\(targetQ)",
                name: ing.item.name,
                baseItemId: ing.item.id,
                requiredDocId: requiredDocId,
                quality: targetQ,
                neededQty: needed,
                haveQty: have,
                missingQty: missing
            )
        }
    }

    /// Scaled first output (for UI). First output only.
    func scaledOutput(for recipe: Recipe) -> (name: String, qty: Double)? {
        guard let out = recipe.outputItems.first else { return nil }
        let mult = BuildingLevelCatalog.throughputMultiplier(forLevel: currentBuilding.level)
        let targetQ = max(1, min(maxOutputQuality, selectedOutputQuality))

        let qty = out.item.isFractional
            ? BuildingLevelCatalog.scaleQuantityFractional(out.quantity, throughputMultiplier: mult)
            : BuildingLevelCatalog.scaleQuantity(out.quantity, throughputMultiplier: mult)

        // Keep icon lookup stable by returning the raw item name (resourceAssetName expects exact keywords).
        _ = targetQ // quality is shown by the UI separately.
        return (out.item.name, qty)
    }

    @MainActor
    private func loadInventoryOnly() {
        inventoryService.fetchInventory(for: userID) { [weak self] result in
            guard let self else { return }
            DispatchQueue.main.async {
                if case .success(let items) = result {
                    self.inventoryItems = items
                }
            }
        }
    }

    // MARK: - "Buy missing" UX
    func openBuyMissingConfirmation(for recipe: Recipe) {
        guard !isBuyingMissing,
              !isGeneratingBuyMissingConfirmation,
              (currentBuilding.isListedOnMarket ?? false) == false,
              currentBuilding.isProducing != true
        else { return }

        let missingInputs = scaledInputs(for: recipe).filter { $0.missingQty > 0.0000001 }
        guard !missingInputs.isEmpty else { return }

        let missingLines: [MissingInputLine] = missingInputs.map {
            MissingInputLine(name: $0.name, baseItemId: $0.baseItemId, quality: $0.quality, missingQty: $0.missingQty)
        }

        buyMissingErrorMessage = nil
        buyMissingConfirmationTitle = "Buy Missing Inputs"
        showBuyMissingConfirmationSheet = false
        buyMissingConfirmationOptions = []
        selectedBuyMissingConfirmationOptionIndex = 0

        isGeneratingBuyMissingConfirmation = true
        marketListingService.fetchAllListings { [weak self] result in
            guard let self else { return }
            Task { @MainActor in
                self.isGeneratingBuyMissingConfirmation = false
                switch result {
                case .failure(let error):
                    self.buyMissingErrorMessage = error.localizedDescription
                case .success(let listings):
                    let plans = self.buildBuyPlans(for: missingLines, from: listings)
                    guard !plans.isEmpty else {
                        self.buyMissingErrorMessage = "Not enough market supply to buy the missing inputs to start production."
                        return
                    }
                    self.buyMissingConfirmationOptions = plans
                    self.selectedBuyMissingConfirmationOptionIndex = 0
                    self.showBuyMissingConfirmationSheet = true
                }
            }
        }
    }

    func openBuyMissingFuelConfirmation() {
        guard !isBuyingMissing,
              !isGeneratingBuyMissingConfirmation,
              (currentBuilding.isListedOnMarket ?? false) == false,
              currentBuilding.isProducing != true
        else { return }

        let mult = BuildingLevelCatalog.throughputMultiplier(forLevel: currentBuilding.level)
        let fuelNeed = BuildingLevelCatalog.scaleQuantity(ProductionService.baseFuelPerExtractorCycle, throughputMultiplier: mult)
        let targetQ = max(1, min(maxOutputQuality, selectedOutputQuality))

        let fuelDocID = ProductionService.fuelDocID(quality: targetQ)
        let have = inventoryQuantity(for: fuelDocID)
        let missingQty = max(0, fuelNeed - have)
        guard missingQty > 0.0000001 else { return }

        let missingLines = [
            MissingInputLine(name: "Fuel Cells", baseItemId: "fuel-cell", quality: targetQ, missingQty: missingQty)
        ]

        buyMissingErrorMessage = nil
        buyMissingConfirmationTitle = "Buy Missing Fuel"
        showBuyMissingConfirmationSheet = false
        buyMissingConfirmationOptions = []
        selectedBuyMissingConfirmationOptionIndex = 0

        isGeneratingBuyMissingConfirmation = true
        marketListingService.fetchAllListings { [weak self] result in
            guard let self else { return }
            Task { @MainActor in
                self.isGeneratingBuyMissingConfirmation = false
                switch result {
                case .failure(let error):
                    self.buyMissingErrorMessage = error.localizedDescription
                case .success(let listings):
                    let plans = self.buildBuyPlans(for: missingLines, from: listings)
                    guard !plans.isEmpty else {
                        self.buyMissingErrorMessage = "Not enough market supply to buy the missing fuel to start production."
                        return
                    }
                    self.buyMissingConfirmationOptions = plans
                    self.selectedBuyMissingConfirmationOptionIndex = 0
                    self.showBuyMissingConfirmationSheet = true
                }
            }
        }
    }

    func confirmBuyMissingSelection() {
        guard !isBuyingMissing,
              selectedBuyMissingConfirmationOptionsIndexValid
        else { return }

        let selectedPlan = buyMissingConfirmationOptions[selectedBuyMissingConfirmationOptionIndex]

        isBuyingMissing = true
        buyMissingErrorMessage = nil

        var currentIndex = 0
        let tasks = selectedPlan.tasks

        func step() {
            guard tasks.indices.contains(currentIndex) else {
                self.isBuyingMissing = false
                self.buyMissingErrorMessage = nil
                self.showBuyMissingConfirmationSheet = false
                NotificationCenter.default.post(
                    name: Notification.Name("marketResourceListingsChanged"),
                    object: nil
                )
                self.loadInventoryOnly()
                return
            }

            let task = tasks[currentIndex]
            self.marketListingService.buyFromListing(
                for: self.userID,
                listing: task.listing
            ) { [weak self] buyResult in
                guard let self else { return }
                Task { @MainActor in
                    switch buyResult {
                    case .failure(let error):
                        self.isBuyingMissing = false
                        self.buyMissingErrorMessage = error.localizedDescription
                    case .success:
                        currentIndex += 1
                        step()
                    }
                }
            }
        }

        step()
    }

    // MARK: - Buy plan building

    private var selectedBuyMissingConfirmationOptionsIndexValid: Bool {
        (0..<buyMissingConfirmationOptions.count).contains(selectedBuyMissingConfirmationOptionIndex)
    }

    private func buildBuyPlans(for missingInputs: [MissingInputLine], from listings: [MarketListing]) -> [BuyMissingPlan] {
        // Market rule: each purchase is an entire listing (no partial fills). Plans show real listing sizes.
        let plan1Tasks = cheapestWholeListingTasks(for: missingInputs, from: listings)
        let plan2Tasks = fewestWholeListingTasks(for: missingInputs, from: listings)

        var plans: [BuyMissingPlan] = []
        if let t = plan1Tasks { plans.append(makePlan(title: "Cheapest full listings", tasks: t)) }
        if let t = plan2Tasks, buyPlanSignature(t) != buyPlanSignature(plan1Tasks ?? []) {
            plans.append(makePlan(title: "Fewest purchases", tasks: t))
        }

        return plans
            .sorted { lhs, rhs in
                if lhs.subtotal != rhs.subtotal { return lhs.subtotal < rhs.subtotal }
                return lhs.tasks.count < rhs.tasks.count
            }
            .prefix(3)
            .map { $0 }
    }

    private func buyPlanSignature(_ tasks: [BuyTask]) -> String {
        tasks.map { "\($0.listing.id):\($0.quantityToBuy)" }.joined(separator: "|")
    }

    private func makePlan(title: String, tasks: [BuyTask]) -> BuyMissingPlan {
        let subtotal = tasks.reduce(0.0) { $0 + ($1.quantityToBuy * $1.listing.pricePerUnit) }
        let fee = subtotal * (MarketCatalog.buyOrderFeePercent / 100)
        let sellerReceives = subtotal - fee
        return BuyMissingPlan(title: title, tasks: tasks, subtotal: subtotal, fee: fee, sellerReceives: sellerReceives)
    }

    /// Buys whole listings only: each `BuyTask.quantityToBuy` equals that listing’s size at plan time.
    private func cheapestWholeListingTasks(for missingInputs: [MissingInputLine], from listings: [MarketListing]) -> [BuyTask]? {
        let epsilon = 0.0000001
        var tasks: [BuyTask] = []
        var usedListingIDs = Set<String>()

        for input in missingInputs {
            var remaining = input.missingQty
            let candidates = listings
                .filter { $0.item.id == input.baseItemId && $0.quality == input.quality && !usedListingIDs.contains($0.id) }
                .sorted { a, b in
                    if a.pricePerUnit != b.pricePerUnit { return a.pricePerUnit < b.pricePerUnit }
                    return a.quantity < b.quantity
                }

            for l in candidates {
                guard remaining > epsilon else { break }
                let fullQty = l.quantity
                guard fullQty > epsilon else { continue }
                tasks.append(BuyTask(listing: l, quantityToBuy: fullQty))
                usedListingIDs.insert(l.id)
                remaining -= fullQty
            }

            guard remaining <= epsilon else { return nil }
        }

        return tasks
    }

    /// Minimize number of separate listings purchased; tie-break by lowest total cost. Falls back to cheapest-whole if search is skipped.
    private func fewestWholeListingTasks(for missingInputs: [MissingInputLine], from listings: [MarketListing]) -> [BuyTask]? {
        var tasks: [BuyTask] = []
        var usedListingIDs = Set<String>()

        for input in missingInputs {
            let candidates = listings
                .filter { $0.item.id == input.baseItemId && $0.quality == input.quality && !usedListingIDs.contains($0.id) }
                .sorted { $0.id < $1.id }

            guard let lineTasks = fewestListingsCoveringNeed(missingQty: input.missingQty, candidates: candidates) else { return nil }
            for t in lineTasks {
                usedListingIDs.insert(t.listing.id)
            }
            tasks.append(contentsOf: lineTasks)
        }

        return tasks.isEmpty ? nil : tasks
    }

    /// Smallest k such that some k listings sum to ≥ need; among those, cheapest total cost.
    private func fewestListingsCoveringNeed(missingQty: Double, candidates: [MarketListing]) -> [BuyTask]? {
        let epsilon = 0.0000001
        let n = candidates.count
        guard n > 0 else { return nil }

        if n <= 14 {
            for k in 1...n {
                var bestCost: Double?
                var bestTasks: [BuyTask]?

                func dfs(_ start: Int, _ picked: [MarketListing]) {
                    if picked.count == k {
                        let sum = picked.reduce(0) { $0 + $1.quantity }
                        if sum + epsilon >= missingQty {
                            let cost = picked.reduce(0) { $0 + $1.quantity * $1.pricePerUnit }
                            if bestCost == nil || cost < bestCost! {
                                bestCost = cost
                                bestTasks = picked.map { BuyTask(listing: $0, quantityToBuy: $0.quantity) }
                            }
                        }
                        return
                    }
                    let needMore = k - picked.count
                    for i in start..<n {
                        if n - i < needMore { break }
                        dfs(i + 1, picked + [candidates[i]])
                    }
                }

                dfs(0, [])
                if let t = bestTasks { return t }
            }
            return nil
        }

        // Many listings: greedy by largest quantity first (fewer purchases heuristically), then by cheaper unit price.
        let sorted = candidates.sorted { a, b in
            if a.quantity != b.quantity { return a.quantity > b.quantity }
            if a.pricePerUnit != b.pricePerUnit { return a.pricePerUnit < b.pricePerUnit }
            return a.id < b.id
        }
        var remaining = missingQty
        var out: [BuyTask] = []
        for l in sorted {
            guard remaining > epsilon else { break }
            out.append(BuyTask(listing: l, quantityToBuy: l.quantity))
            remaining -= l.quantity
        }
        return remaining <= epsilon ? out : nil
    }

    /// Scaled output quantity for first output (for display).
    func scaledOutputQuantityForDisplay() -> Double? {
        guard let r = selectedRecipeForBuilding ?? recipe, let out = r.outputItems.first else { return nil }
        let mult = BuildingLevelCatalog.throughputMultiplier(forLevel: currentBuilding.level)
        return out.item.isFractional
            ? BuildingLevelCatalog.scaleQuantityFractional(out.quantity, throughputMultiplier: mult)
            : BuildingLevelCatalog.scaleQuantity(out.quantity, throughputMultiplier: mult)
    }

    func scaledOutputItemName() -> String? {
        (selectedRecipeForBuilding ?? recipe)?.outputItems.first?.item.name
    }

    /// Scaled input required for current level (throughput multiplier).
    func scaledInputSummary() -> String {
        if isExtractor {
            let mult = BuildingLevelCatalog.throughputMultiplier(forLevel: currentBuilding.level)
            let n = Int(BuildingLevelCatalog.scaleQuantity(ProductionService.baseFuelPerExtractorCycle, throughputMultiplier: mult))
            return n == 1 ? "1 Fuel Cell" : "\(n) Fuel Cells"
        }
        guard let r = selectedRecipeForBuilding ?? recipe else { return "—" }
        let mult = BuildingLevelCatalog.throughputMultiplier(forLevel: currentBuilding.level)
        return r.inputItems.map { ing in
            let qty = ing.item.isFractional
                ? BuildingLevelCatalog.scaleQuantityFractional(ing.quantity, throughputMultiplier: mult)
                : BuildingLevelCatalog.scaleQuantity(ing.quantity, throughputMultiplier: mult)
            return (ing.item.isFractional ? NumberFormatting.decimal(qty, fractionDigits: 1) : NumberFormatting.integer(Int(qty))) + " \(ing.item.name)"
        }.joined(separator: ", ")
    }

    /// Scaled output per cycle for current level.
    func scaledOutputSummary() -> String {
        if isExtractor {
            return "Raw \(currentBuilding.resourceType?.rawValue ?? "resource") (variable)"
        }
        guard let r = selectedRecipeForBuilding ?? recipe, let out = r.outputItems.first else { return "—" }
        let mult = BuildingLevelCatalog.throughputMultiplier(forLevel: currentBuilding.level)
        let qty = out.item.isFractional
            ? BuildingLevelCatalog.scaleQuantityFractional(out.quantity, throughputMultiplier: mult)
            : BuildingLevelCatalog.scaleQuantity(out.quantity, throughputMultiplier: mult)
        return (out.item.isFractional ? NumberFormatting.decimal(qty, fractionDigits: 1) : NumberFormatting.integer(Int(qty))) + " \(out.item.name)"
    }

    /// Next production end time (building-level).
    func nextProductionEndTime() -> Date? {
        guard currentBuilding.isProducing == true, let end = currentBuilding.productionEndsAt, end > Date() else { return nil }
        return end
    }

    func suggestedPricing() -> (startingBid: Double, suggestedBuyNowLow: Double, suggestedBuyNowHigh: Double)? {
        guard
            let resourceType = currentBuilding.resourceType,
            let abundance = currentBuilding.abundance
        else {
            return nil
        }

        let baseValue: Double
        switch resourceType {
        case .gold: baseValue = 800
        case .silver: baseValue = 700
        case .diamond: baseValue = 1200
        case .oil: baseValue = 900
        case .coal: baseValue = 650
        case .iron: baseValue = 750
        case .quarry, .sandQuarry, .stoneQuarry, .gravelQuarry: baseValue = 700
        default: baseValue = 700
        }

        let statBonus = Double(abundance - 50) * 24.0
        let levelBonus = Double(currentBuilding.level - 1) * 150.0
        let startingBid = max(100, baseValue + statBonus + levelBonus)
        let suggestedBuyNowLow = startingBid * 1.35
        let suggestedBuyNowHigh = startingBid * 1.75
        return (startingBid, suggestedBuyNowLow, suggestedBuyNowHigh)
    }

    func formattedTimeRemaining(until endDate: Date, now: Date) -> String {
        let remainingSeconds = max(0, Int(ceil(endDate.timeIntervalSince(now))))
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Output per cycle (deterministic). Abundance sets base; level adds % bonus.
    func formattedOutputPerCycle() -> String {
        guard let abundance = currentBuilding.abundance else { return "Unknown" }
        let output = ProductionService.extractorOutput(
            abundance: abundance,
            level: currentBuilding.level,
            resourceType: currentBuilding.resourceType
        )
        return "\(output)"
    }

    /// Output at next level (for upgrade incentive). Nil if max level.
    func formattedOutputAtNextLevel() -> String? {
        guard
            let abundance = currentBuilding.abundance,
            currentBuilding.level < BuildingService.maxBuildingLevel
        else { return nil }
        let nextLevel = currentBuilding.level + 1
        let output = ProductionService.extractorOutput(
            abundance: abundance,
            level: nextLevel,
            resourceType: currentBuilding.resourceType
        )
        return "\(output)"
    }

    func scrapValue() -> Double {
        // Keep sell-to-system punitive but coherent with purchase prices.
        // Target baseline recovery: ~24% of purchase cost, +3% per level above 1.
        if let purchaseCost = BuildingCatalog.cost(forBuildingName: currentBuilding.name) {
            let levelBonusPct = min(0.12, 0.03 * Double(max(0, currentBuilding.level - 1)))
            let abundanceBonusPct: Double
            if currentBuilding.resourceType != nil {
                // Extractors get a small abundance sensitivity on resale.
                abundanceBonusPct = Double((currentBuilding.abundance ?? 50) - 50) * 0.001
            } else {
                abundanceBonusPct = 0
            }
            let pct = max(0.18, min(0.45, 0.24 + levelBonusPct + abundanceBonusPct))
            return (purchaseCost * pct).rounded()
        }

        // Fallback for legacy/unmapped building names.
        switch currentBuilding.type {
        case .refinery: return 20_000
        case .plant: return 28_000
        case .shop: return 35_000
        case .mill: return 24_000
        case .researchAndDevelopment: return 42_000
        default: return 15_000
        }
    }

    var isExtractor: Bool {
        currentBuilding.type == .mine || currentBuilding.type == .rig || currentBuilding.type == .quarry
    }

    /// Throughput multiplier for display. Extractors use smaller output multiplier; others use recipe throughput.
    var throughputMultiplier: Double {
        if isExtractor {
            return BuildingLevelCatalog.extractorOutputMultiplier(forLevel: currentBuilding.level)
        }
        return BuildingLevelCatalog.throughputMultiplier(forLevel: currentBuilding.level)
    }

    /// Scaled input summary for a specific recipe at current level.
    func productionInputSummary(for recipe: Recipe) -> String {
        if recipe.inputItems.isEmpty { return "—" }
        let mult = BuildingLevelCatalog.throughputMultiplier(forLevel: currentBuilding.level)
        return recipe.inputItems.map { ing in
            let qty = ing.item.isFractional
                ? BuildingLevelCatalog.scaleQuantityFractional(ing.quantity, throughputMultiplier: mult)
                : BuildingLevelCatalog.scaleQuantity(ing.quantity, throughputMultiplier: mult)
            return (ing.item.isFractional ? NumberFormatting.decimal(qty, fractionDigits: 1) : NumberFormatting.integer(Int(qty))) + " \(ing.item.name)"
        }.joined(separator: ", ")
    }
}
