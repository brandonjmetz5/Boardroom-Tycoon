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

    func buyMissing(for recipe: Recipe) {
        guard !isBuyingMissing, (currentBuilding.isListedOnMarket ?? false) == false, currentBuilding.isProducing != true else { return }

        let targetQ = max(1, min(maxOutputQuality, selectedOutputQuality))
        let missingInputs = scaledInputs(for: recipe).filter { $0.missingQty > 0.0000001 }
        guard !missingInputs.isEmpty else { return }

        isBuyingMissing = true
        buyMissingErrorMessage = nil

        marketListingService.fetchAllListings { [weak self] result in
            guard let self else { return }
            Task { @MainActor in
                switch result {
                case .failure(let error):
                    self.isBuyingMissing = false
                    self.buyMissingErrorMessage = error.localizedDescription
                case .success(let listings):
                    var tasks: [(listing: MarketListing, qty: Double)] = []

                    for input in missingInputs {
                        let candidates = listings
                            .filter { $0.item.id == input.baseItemId && $0.quality == input.quality }
                            .sorted { $0.pricePerUnit < $1.pricePerUnit }

                        var remaining = input.missingQty
                        for l in candidates {
                            guard remaining > 0.0000001 else { break }
                            let buyQty = min(l.quantity, remaining)
                            if buyQty > 0 {
                                tasks.append((listing: l, qty: buyQty))
                                remaining -= buyQty
                            }
                        }

                        if remaining > 0.0000001 {
                            self.isBuyingMissing = false
                            self.buyMissingErrorMessage = "Not enough market supply to buy missing \(input.name) (Q\(targetQ))."
                            return
                        }
                    }

                    var currentIndex = 0

                    @MainActor
                    func step() {
                        guard tasks.indices.contains(currentIndex) else {
                            self.isBuyingMissing = false
                            self.buyMissingErrorMessage = nil
                            self.loadInventoryOnly()
                            return
                        }

                        let task = tasks[currentIndex]
                        self.marketListingService.buyPartialFromListing(
                            for: self.userID,
                            listing: task.listing,
                            quantityToBuy: task.qty
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
            }
        }
    }

    func buyMissingForExtractorFuel() {
        guard !isBuyingMissing, (currentBuilding.isListedOnMarket ?? false) == false, currentBuilding.isProducing != true else { return }

        let mult = BuildingLevelCatalog.throughputMultiplier(forLevel: currentBuilding.level)
        let fuelNeed = BuildingLevelCatalog.scaleQuantity(ProductionService.baseFuelPerExtractorCycle, throughputMultiplier: mult)
        let targetQ = max(1, min(maxOutputQuality, selectedOutputQuality))

        let fuelDocID = ProductionService.fuelDocID(quality: targetQ)
        let have = inventoryQuantity(for: fuelDocID)
        let missingQty = max(0, fuelNeed - have)
        guard missingQty > 0.0000001 else { return }

        isBuyingMissing = true
        buyMissingErrorMessage = nil

        marketListingService.fetchAllListings { [weak self] result in
            guard let self else { return }
            Task { @MainActor in
                switch result {
                case .failure(let error):
                    self.isBuyingMissing = false
                    self.buyMissingErrorMessage = error.localizedDescription
                case .success(let listings):
                    let candidates = listings
                        .filter { $0.item.id == "fuel-cell" && $0.quality == targetQ }
                        .sorted { $0.pricePerUnit < $1.pricePerUnit }

                    var remaining = missingQty
                    var tasks: [(listing: MarketListing, qty: Double)] = []
                    for l in candidates {
                        guard remaining > 0.0000001 else { break }
                        let buyQty = min(l.quantity, remaining)
                        if buyQty > 0 {
                            tasks.append((listing: l, qty: buyQty))
                            remaining -= buyQty
                        }
                    }

                    if remaining > 0.0000001 {
                        self.isBuyingMissing = false
                        self.buyMissingErrorMessage = "Not enough market supply to buy missing Fuel Cells (Q\(targetQ))."
                        return
                    }

                    var currentIndex = 0

                    @MainActor
                    func step() {
                        guard tasks.indices.contains(currentIndex) else {
                            self.isBuyingMissing = false
                            self.buyMissingErrorMessage = nil
                            self.loadInventoryOnly()
                            return
                        }

                        let task = tasks[currentIndex]
                        self.marketListingService.buyPartialFromListing(
                            for: self.userID,
                            listing: task.listing,
                            quantityToBuy: task.qty
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
            }
        }
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
            return (ing.item.isFractional ? String(format: "%.1f", qty) : "\(Int(qty))") + " \(ing.item.name)"
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
        return (out.item.isFractional ? String(format: "%.1f", qty) : "\(Int(qty))") + " \(out.item.name)"
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
        if let resourceType = currentBuilding.resourceType {
            let baseValue: Double
            switch resourceType {
            case .gold: baseValue = 500
            case .silver: baseValue = 425
            case .diamond: baseValue = 700
            case .oil: baseValue = 550
            case .coal: baseValue = 400
            case .iron: baseValue = 450
            case .quarry, .sandQuarry, .stoneQuarry, .gravelQuarry: baseValue = 400
            default: baseValue = 400
            }
            let abundanceBonus = Double((currentBuilding.abundance ?? 50) - 50) * 8.0
            let levelBonus = Double(currentBuilding.level - 1) * 100.0
            return max(100, baseValue + abundanceBonus + levelBonus)
        }
        switch currentBuilding.type {
        case .refinery: return 400
        case .plant: return 450
        case .shop: return 500
        case .mill: return 350
        default: return 250
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
            return (ing.item.isFractional ? String(format: "%.1f", qty) : "\(Int(qty))") + " \(ing.item.name)"
        }.joined(separator: ", ")
    }
}
