//
//  ResearchAndDevelopmentViewModel.swift
//  Boardroom Tycoon
//
//  View model for the Research & Development building.
//

import Foundation
import Combine

@MainActor
final class ResearchAndDevelopmentViewModel: ObservableObject {
    let userID: String
    @Published private(set) var currentBuilding: Building

    @Published private(set) var profile: PlayerProfile?
    @Published private(set) var items: [Item] = []
    @Published private(set) var qualities: [ResourceQuality] = []

    @Published private(set) var isLoading = true
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?

    /// Number of research points the player wants to apply when upgrading a resource.
    @Published var pointsToApplyText: String = "50"

    private let playerProfileService = PlayerProfileService()
    private let buildingService = BuildingService()
    private let itemService = ItemService()
    private let qualityService = ResourceQualityService()
    private let productionService = ProductionService()

    init(userID: String, building: Building) {
        self.userID = userID
        self.currentBuilding = building
    }

    /// Items grouped by category for organized display.
    var itemsByCategory: [(category: ItemCategory, items: [Item])] {
        let grouped = Dictionary(grouping: items) { $0.category }
        return ItemCategory.allCases.compactMap { cat in
            guard let list = grouped[cat], !list.isEmpty else { return nil }
            return (cat, list.sorted { $0.name < $1.name })
        }
    }

    /// Cycle is running and not yet ready to collect.
    var isCycleRunning: Bool {
        currentBuilding.isProducing == true && !isReadyToCollect
    }

    /// Cycle finished, ready to collect.
    var isReadyToCollect: Bool {
        guard currentBuilding.isProducing == true,
              let endsAt = currentBuilding.productionEndsAt else { return false }
        return endsAt <= Date()
    }

    /// Time remaining in cycle (nil if not producing or ready).
    func timeRemaining(now: Date = Date()) -> String? {
        guard currentBuilding.isProducing == true,
              let endsAt = currentBuilding.productionEndsAt,
              endsAt > now else { return nil }
        let remaining = max(0, Int(ceil(endsAt.timeIntervalSince(now))))
        let m = remaining / 60
        let s = remaining % 60
        return String(format: "%02d:%02d", m, s)
    }

    /// Progress 0...1 for circular timer (elapsed / total).
    func cycleProgress(now: Date = Date()) -> CGFloat {
        guard currentBuilding.isProducing == true,
              let startedAt = currentBuilding.productionStartedAt,
              let endsAt = currentBuilding.productionEndsAt,
              endsAt > startedAt else { return 0 }
        let total = endsAt.timeIntervalSince(startedAt)
        let elapsed = now.timeIntervalSince(startedAt)
        return CGFloat(min(1, max(0, elapsed / total)))
    }

    /// Cash cost for the next research cycle at current building level.
    var researchCycleCost: Double {
        ProductionService.researchCycleCost(forLevel: currentBuilding.level)
    }

    /// Output range text for the research cycle (e.g. "10–20 pts").
    var researchCycleOutputRangeText: String {
        let range = ProductionService.researchPointsOutputRange(forLevel: currentBuilding.level)
        return "\(range.lowerBound)–\(range.upperBound) pts"
    }

    // MARK: - Lab upgrade

    /// Whether the R&D building can be upgraded.
    var canUpgradeLab: Bool {
        currentBuilding.level < BuildingService.maxBuildingLevel && (currentBuilding.isListedOnMarket ?? false) == false
    }

    /// Cash cost to upgrade the lab to the next level.
    var labUpgradeCashCost: Double {
        let targetLevel = currentBuilding.level + 1
        return (BuildingService.baseUpgradeCashCost * BuildingLevelCatalog.upgradeCostMultiplier(forTargetLevel: targetLevel)).rounded()
    }

    /// Human-readable material requirements for upgrading the lab.
    var labUpgradeRequirementLabel: String {
        UpgradeCatalog.buildingUpgradeRequirementLabel(forLevel: currentBuilding.level)
    }

    func upgradeLab() {
        guard canUpgradeLab else { return }
        isWorking = true
        errorMessage = nil
        buildingService.upgradeBuildingLevel(for: userID, buildingID: currentBuilding.id) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isWorking = false
                switch result {
                case .success:
                    self.refreshBuilding()
                    self.reloadProfile()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func loadData() {
        isLoading = true
        errorMessage = nil

        let group = DispatchGroup()

        group.enter()
        buildingService.fetchBuildings(for: userID) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                if case .success(let buildings) = result,
                   let rd = buildings.first(where: { $0.id == self.currentBuilding.id }) {
                    self.currentBuilding = rd
                }
                group.leave()
            }
        }

        group.enter()
        playerProfileService.fetchPlayerProfile(for: userID) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                if case .success(let profile) = result {
                    self.profile = profile
                }
                group.leave()
            }
        }

        group.enter()
        itemService.fetchItems { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                if case .success(let items) = result, !items.isEmpty {
                    self.items = items.sorted { $0.name < $1.name }
                } else {
                    self.items = RecipeCatalog.researchableItems()
                }
                group.leave()
            }
        }

        group.enter()
        qualityService.fetchQualities(for: userID) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                if case .success(let qualities) = result {
                    self.qualities = qualities
                }
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            self?.isLoading = false
        }
    }

    private func refreshBuilding() {
        buildingService.fetchBuildings(for: userID) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                if case .success(let buildings) = result,
                   let rd = buildings.first(where: { $0.id == self.currentBuilding.id }) {
                    self.currentBuilding = rd
                }
            }
        }
    }

    func startResearchCycle() {
        isWorking = true
        errorMessage = nil
        productionService.startResearchCycle(for: userID, buildingID: currentBuilding.id) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isWorking = false
                switch result {
                case .success:
                    self.refreshBuilding()
                    self.reloadProfile()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func collectResearch() {
        isWorking = true
        errorMessage = nil
        productionService.collectProduction(for: userID, buildingID: currentBuilding.id) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isWorking = false
                switch result {
                case .success:
                    self.refreshBuilding()
                    self.reloadProfile()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func reloadProfile() {
        playerProfileService.fetchPlayerProfile(for: userID) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                if case .success(let profile) = result {
                    self.profile = profile
                }
            }
        }
    }

    func currentQuality(for item: Item) -> ResourceQuality? {
        qualities.first(where: { $0.id == item.id })
    }

    func requiredPoints(forLevel level: Int) -> Int {
        ResourceQualityService.requiredResearchPoints(forLevel: level)
    }

    func applyResearchPoints(to item: Item, amount: Int? = nil) {
        guard let profile else {
            errorMessage = "Profile not loaded."
            return
        }
        let available = profile.researchPoints
        let points = amount ?? Int(pointsToApplyText) ?? 0
        if points <= 0 {
            errorMessage = "Enter a positive number of points to apply."
            return
        }
        if points > available {
            errorMessage = "Not enough research points. You have \(available)."
            return
        }

        isWorking = true
        errorMessage = nil
        qualityService.addResearchPoints(for: userID, itemID: item.id, points: points) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isWorking = false
                switch result {
                case .success:
                    self.loadData()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

