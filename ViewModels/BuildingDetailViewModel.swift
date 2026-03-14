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
    @Published private(set) var machines: [Machine] = []
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?
    /// All recipes for this building (one for refineries, three for Fabrication Plant, etc.).
    @Published private(set) var recipes: [Recipe] = []
    /// Single recipe when building has only one (convenience for UI).
    var recipe: Recipe? { recipes.first }
    /// For multi-recipe buildings, the one recipe used when starting all machines.
    @Published var selectedRecipeForBuilding: Recipe?

    @Published private(set) var inventoryItems: [InventoryItem] = []

    @Published var showListingSheet = false
    @Published var buyNowPriceText = ""

    private let productionService = ProductionService()
    private let buildingService = BuildingService()
    private let mineMarketService = MineMarketService()
    private let recipeService = RecipeService()
    private let inventoryService = InventoryService()

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
                        self.loadMachines()
                        self.loadInventory()
                    }
                case .failure:
                    break
                }
            }
        }
    }

    private func loadMachines() {
        buildingService.fetchMachines(for: userID, buildingID: currentBuilding.id) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(var list):
                    if self.isExtractor, list.isEmpty, self.currentBuilding.abundance != nil, self.currentBuilding.stability != nil {
                        self.buildingService.ensureFirstExtractorMachine(for: self.userID, building: self.currentBuilding) { [weak self] ensureResult in
                            DispatchQueue.main.async {
                                guard let self else { return }
                                if case .success = ensureResult {
                                    self.buildingService.fetchMachines(for: self.userID, buildingID: self.currentBuilding.id) { r in
                                        DispatchQueue.main.async {
                                            if case .success(let m) = r { self.machines = m }
                                        }
                                    }
                                } else {
                                    self.machines = list
                                }
                            }
                        }
                        return
                    }
                    if !self.isExtractor, list.isEmpty, self.currentBuilding.capacity >= 1 {
                        self.buildingService.ensureFirstNonExtractorMachine(for: self.userID, building: self.currentBuilding) { [weak self] ensureResult in
                            DispatchQueue.main.async {
                                guard let self else { return }
                                if case .success = ensureResult {
                                    self.buildingService.fetchMachines(for: self.userID, buildingID: self.currentBuilding.id) { r in
                                        DispatchQueue.main.async {
                                            if case .success(let m) = r { self.machines = m }
                                        }
                                    }
                                } else {
                                    self.machines = list
                                }
                            }
                        }
                        return
                    }
                    self.machines = list
                case .failure:
                    self.machines = []
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
    }

    private func loadInventory() {
        inventoryService.fetchInventory(for: userID) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                if case .success(let items) = result { self.inventoryItems = items }
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

    /// Start production on a single machine. For extractors pass nil for recipe; for recipe buildings pass the chosen recipe.
    func startProductionForMachine(_ machine: Machine, recipe: Recipe?) {
        isWorking = true
        errorMessage = nil
        if isExtractor {
            guard let rt = currentBuilding.resourceType,
                  let a = machine.abundance ?? currentBuilding.abundance,
                  let s = machine.stability ?? currentBuilding.stability else {
                isWorking = false
                errorMessage = "Missing mine stats."
                return
            }
            productionService.startProductionForMachine(for: userID, buildingID: currentBuilding.id, machineID: machine.id, resourceType: rt, abundance: a, stability: s) { [weak self] result in
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
            guard let r = recipe ?? recipes.first else {
                isWorking = false
                errorMessage = "No recipe configured for this building."
                return
            }
            productionService.startRecipeProductionForMachine(for: userID, buildingID: currentBuilding.id, machineID: machine.id, building: currentBuilding, recipe: r) { [weak self] result in
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

    func collectProductionForMachine(_ machine: Machine) {
        isWorking = true
        errorMessage = nil
        let qty = machine.pendingOutputQuantity ?? 0
        let outId = machine.pendingOutputItemId
        let outName = machine.pendingOutputItemName
        productionService.collectProductionForMachine(for: userID, buildingID: currentBuilding.id, machineID: machine.id, resourceType: isExtractor ? currentBuilding.resourceType : nil, pendingOutputQuantity: qty, pendingOutputItemId: outId, pendingOutputItemName: outName) { [weak self] result in
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

    /// Start production on all machines (all-or-nothing). Uses selectedRecipeForBuilding for recipe buildings.
    func startProductionForAllMachines() {
        guard canStartAllMachines else { return }
        isWorking = true
        errorMessage = nil
        let recipeToUse = selectedRecipeForBuilding ?? recipe
        productionService.startProductionForAllMachines(for: userID, building: currentBuilding, machines: machines, recipe: isExtractor ? nil : recipeToUse) { [weak self] result in
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

    /// Collect from every machine that is ready.
    func collectAllProduction() {
        isWorking = true
        errorMessage = nil
        productionService.collectProductionForAllMachines(for: userID, building: currentBuilding, machines: machines) { [weak self] result in
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

    func addMachine() {
        isWorking = true
        errorMessage = nil
        buildingService.addMachine(for: userID, building: currentBuilding, isExtractor: isExtractor) { [weak self] result in
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

    func upgradeMachine(_ machine: Machine) {
        isWorking = true
        errorMessage = nil
        buildingService.upgradeMachine(for: userID, buildingID: currentBuilding.id, machineID: machine.id, buildingType: currentBuilding.type, isExtractor: isExtractor) { [weak self] result in
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

    // MARK: - Display helpers

    var addMachineCost: Double {
        BuildingService.addMachineCashCost(currentMachineCount: machines.count)
    }

    var canAddMachine: Bool {
        machines.count < currentBuilding.capacity && (currentBuilding.isListedOnMarket ?? false) == false
    }

    var canUpgradeBuilding: Bool {
        currentBuilding.level < BuildingService.maxBuildingLevel && (currentBuilding.isListedOnMarket ?? false) == false
    }

    func canUpgradeMachine(_ machine: Machine) -> Bool {
        if isExtractor {
            let a = machine.abundance ?? 0
            let s = machine.stability ?? 0
            return a < Machine.maxAbundanceStability || s < Machine.maxAbundanceStability
        }
        let out = machine.outputValuePerCycle ?? Machine.defaultOutputValuePerCycle
        return out < Machine.maxOutputValuePerCycle
    }

    func isReadyToCollect(at date: Date) -> Bool {
        guard let productionEndsAt = currentBuilding.productionEndsAt else { return false }
        return currentBuilding.isProducing == true && productionEndsAt <= date
    }

    func isMachineProducing(_ machine: Machine) -> Bool {
        (machine.isProducing ?? false)
    }

    func isMachineReadyToCollect(_ machine: Machine, at date: Date) -> Bool {
        guard (machine.isProducing ?? false), let endsAt = machine.productionEndsAt else { return false }
        return endsAt <= date
    }

    var hasAnyMachineProducing: Bool {
        machines.contains { $0.isProducing == true }
    }

    /// At least one machine has finished and can be collected.
    var hasAnyMachineReadyToCollect: Bool {
        let now = Date()
        return machines.contains { isMachineReadyToCollect($0, at: now) }
    }

    /// Can start production on all machines (none producing, enough resources for every machine).
    var canStartAllMachines: Bool {
        guard !machines.isEmpty, (currentBuilding.isListedOnMarket ?? false) == false else { return false }
        if hasAnyMachineProducing { return false }
        if isExtractor {
            let fuelNeed = ProductionService.fuelRequiredPerCycle * Double(machines.count)
            return inventoryQuantity(for: "fuel-cell") >= fuelNeed
        }
        guard let r = selectedRecipeForBuilding ?? recipe else { return false }
        for input in r.inputItems {
            let need = input.quantity * Double(machines.count)
            if inventoryQuantity(for: input.item.id) < need { return false }
        }
        return true
    }

    func inventoryQuantity(for itemId: String) -> Double {
        inventoryItems.first(where: { $0.item.id == itemId })?.quantity ?? 0
    }

    /// Total input required to start all machines (e.g. "10 Fuel Cells" for 5 extractors).
    func totalInputSummaryForAllMachines() -> String {
        if isExtractor {
            let n = Int(ProductionService.fuelRequiredPerCycle * Double(machines.count))
            return "\(n) Fuel Cells"
        }
        guard let r = selectedRecipeForBuilding ?? recipe else { return "—" }
        return r.inputItems.map { "\(Int($0.quantity * Double(machines.count))) \($0.item.name)" }.joined(separator: ", ")
    }

    /// Total output per cycle when all machines run (e.g. "5 Gold Bar" for 1 machine, "25 Gold Bar" for 5).
    func totalOutputSummaryForAllMachines() -> String {
        if isExtractor {
            return "Raw \(currentBuilding.resourceType?.rawValue ?? "resource") (varies by machine)"
        }
        guard let r = selectedRecipeForBuilding ?? recipe, let out = r.outputItems.first else { return "—" }
        let total = out.quantity * Double(machines.count)
        return (out.item.isFractional ? String(format: "%.1f", total) : "\(Int(total))") + " \(out.item.name)"
    }

    /// Next production end time among producing machines (for countdown).
    func nextProductionEndTime() -> Date? {
        machines.compactMap { m -> Date? in
            guard m.isProducing == true, let end = m.productionEndsAt, end > Date() else { return nil }
            return end
        }.min()
    }

    func suggestedPricing() -> (startingBid: Double, suggestedBuyNowLow: Double, suggestedBuyNowHigh: Double)? {
        guard
            let resourceType = currentBuilding.resourceType,
            let abundance = currentBuilding.abundance,
            let stability = currentBuilding.stability
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

        let statBonus = Double((abundance - 50) + (stability - 50)) * 12.0
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

    func formattedOutputRange() -> String {
        guard
            let abundance = currentBuilding.abundance,
            let stability = currentBuilding.stability
        else {
            return "Unknown"
        }

        let maxOutput = max(1, abundance - 40)
        let normalizedStability = Double(stability - 50) / 50.0
        let stabilityMultiplier = 0.5 + (normalizedStability * 0.4)
        let minOutput = max(1, Int((Double(maxOutput) * stabilityMultiplier).rounded(.down)))
        return "\(minOutput)-\(maxOutput)"
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
            let abundanceBonus = Double((currentBuilding.abundance ?? 50) - 50) * 4.0
            let stabilityBonus = Double((currentBuilding.stability ?? 50) - 50) * 4.0
            let levelBonus = Double(currentBuilding.level - 1) * 100.0
            return max(100, baseValue + abundanceBonus + stabilityBonus + levelBonus)
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

    /// Text describing what input is required to start production (e.g. "2 Fuel Cells").
    var productionInputSummary: String {
        if isExtractor {
            let n = Int(ProductionService.fuelRequiredPerCycle)
            return n == 1 ? "1 Fuel Cell" : "\(n) Fuel Cells"
        }
        guard let recipe = recipe, !recipe.inputItems.isEmpty else {
            return "Recipe inputs"
        }
        return recipe.inputItems.map { "\(Int($0.quantity)) \($0.item.name)" }.joined(separator: ", ")
    }

    func productionInputSummary(for recipe: Recipe) -> String {
        if recipe.inputItems.isEmpty { return "—" }
        return recipe.inputItems.map { "\(Int($0.quantity)) \($0.item.name)" }.joined(separator: ", ")
    }
}
