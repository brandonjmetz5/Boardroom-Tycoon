//
//  OperationsViewModel.swift
//  Boardroom Tycoon
//
//  MVVM: Presentation logic and state for the Operations (buildings/slots) screen.
//

import Foundation
import Combine

/// Status used by the view to choose label and color for a building card.
enum BuildingStatusDisplay {
    case listed
    case ready
    case producing
    case idle
}

@MainActor
final class OperationsViewModel: ObservableObject {
    let userID: String

    // MARK: - State

    @Published private(set) var buildings: [Building] = []
    @Published private(set) var profile: PlayerProfile?
    @Published private(set) var prospectingJobs: [ProspectingJob] = []
    @Published private(set) var isLoading = true
    @Published private(set) var loadingErrorMessage: String?
    @Published var purchaseErrorMessage: String?
    @Published var showPurchaseSheet = false
    @Published private(set) var isPurchasing = false
    @Published var selectedEmptySlotIndex: Int?

    // MARK: - Services

    private let buildingService = BuildingService()
    private let playerProfileService = PlayerProfileService()
    private let prospectingService = ProspectingService()
    private let mineMarketService = MineMarketService()

    init(userID: String) {
        self.userID = userID
    }

    // MARK: - Actions

    /// Call on appear; settles expired mine listings then loads profile, buildings, and prospecting jobs.
    func loadData() {
        mineMarketService.settleExpiredMineListings { [weak self] _ in
            self?.performLoad()
        }
    }

    private func performLoad() {
        isLoading = true
        loadingErrorMessage = nil

        let group = DispatchGroup()

        group.enter()
        playerProfileService.fetchPlayerProfile(for: userID) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let loadedProfile):
                    self.profile = loadedProfile
                case .failure(let error):
                    self.loadingErrorMessage = error.localizedDescription
                }
                group.leave()
            }
        }

        group.enter()
        buildingService.fetchBuildings(for: userID) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let loadedBuildings):
                    self.buildings = loadedBuildings
                case .failure(let error):
                    self.loadingErrorMessage = error.localizedDescription
                }
                group.leave()
            }
        }

        group.enter()
        prospectingService.fetchProspectingJobs(for: userID) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let loadedJobs):
                    self.prospectingJobs = loadedJobs
                case .failure(let error):
                    self.loadingErrorMessage = error.localizedDescription
                }
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            self?.isLoading = false
        }
    }

    func purchaseBuilding(_ purchasableBuilding: PurchasableBuilding) {
        guard let selectedEmptySlotIndex else {
            purchaseErrorMessage = "Select an empty slot first."
            return
        }

        isPurchasing = true
        purchaseErrorMessage = nil

        buildingService.purchaseBuilding(
            for: userID,
            purchasableBuilding: purchasableBuilding,
            slotIndex: selectedEmptySlotIndex
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isPurchasing = false
                switch result {
                case .success:
                    self.showPurchaseSheet = false
                    self.selectedEmptySlotIndex = nil
                    self.loadData()
                case .failure(let error):
                    self.purchaseErrorMessage = error.localizedDescription
                }
            }
        }
    }

    func startProspecting(_ resourceType: ResourceType) {
        guard let selectedEmptySlotIndex else {
            purchaseErrorMessage = "Select an empty slot first."
            return
        }

        isPurchasing = true
        purchaseErrorMessage = nil

        prospectingService.startProspecting(
            for: userID,
            resourceType: resourceType,
            slotIndex: selectedEmptySlotIndex
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isPurchasing = false
                switch result {
                case .success:
                    self.showPurchaseSheet = false
                    self.selectedEmptySlotIndex = nil
                    self.loadData()
                case .failure(let error):
                    self.purchaseErrorMessage = error.localizedDescription
                }
            }
        }
    }

    func revealProspectingJob(_ job: ProspectingJob) {
        isPurchasing = true
        purchaseErrorMessage = nil

        prospectingService.revealProspectingJob(for: userID, jobID: job.id) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isPurchasing = false
                switch result {
                case .success:
                    self.loadData()
                case .failure(let error):
                    self.purchaseErrorMessage = error.localizedDescription
                }
            }
        }
    }

    func openPurchaseSheet(slotIndex: Int) {
        purchaseErrorMessage = nil
        selectedEmptySlotIndex = slotIndex
        showPurchaseSheet = true
    }

    func closePurchaseSheet() {
        showPurchaseSheet = false
        selectedEmptySlotIndex = nil
    }

    // MARK: - Computed

    var activeProspectingJobs: [ProspectingJob] {
        prospectingJobs.filter { !$0.isComplete }
    }

    var usedSlotsCount: Int {
        buildings.count + activeProspectingJobs.count
    }

    var totalSlotsCount: Int {
        profile?.buildingSlotCount ?? usedSlotsCount
    }

    var producingCount: Int {
        buildings.filter { building in
            building.isProducing == true && !isReadyToCollect(building: building, now: Date())
        }.count
    }

    var readyCount: Int {
        buildings.filter { isReadyToCollect(building: $0, now: Date()) }.count
    }

    var listedCount: Int {
        buildings.filter { $0.isListedOnMarket == true }.count
    }

    var buildingSlots: [BuildingSlot] {
        let totalSlots = profile?.buildingSlotCount ?? buildings.count
        var slots: [BuildingSlot] = []

        for slotIndex in 0..<totalSlots {
            if let building = buildings.first(where: { $0.slotIndex == slotIndex }) {
                slots.append(
                    BuildingSlot(
                        id: "slot-building-\(building.id)",
                        slotIndex: slotIndex,
                        content: .building(building)
                    )
                )
            } else if let job = activeProspectingJobs.first(where: { $0.slotIndex == slotIndex }) {
                slots.append(
                    BuildingSlot(
                        id: "slot-prospecting-\(job.id)",
                        slotIndex: slotIndex,
                        content: .prospecting(job)
                    )
                )
            } else {
                slots.append(
                    BuildingSlot(
                        id: "slot-empty-\(slotIndex)",
                        slotIndex: slotIndex,
                        content: .empty
                    )
                )
            }
        }

        return slots
    }

    // MARK: - Display helpers (status, labels, asset names)

    func isReadyToCollect(building: Building, now: Date) -> Bool {
        guard
            building.isProducing == true,
            let productionEndsAt = building.productionEndsAt
        else {
            return false
        }
        return productionEndsAt <= now
    }

    func buildingStatus(for building: Building, now: Date) -> BuildingStatusDisplay {
        if building.isListedOnMarket == true {
            return .listed
        }
        if isReadyToCollect(building: building, now: now) {
            return .ready
        }
        if building.isProducing == true {
            return .producing
        }
        return .idle
    }

    func buildingStatusText(for building: Building, now: Date) -> String {
        switch buildingStatus(for: building, now: now) {
        case .listed: return "Listed"
        case .ready: return "Ready"
        case .producing: return "Producing"
        case .idle: return "Idle"
        }
    }

    func buildingDetailText(for building: Building, now: Date) -> String {
        if building.isListedOnMarket == true {
            return "Level \(building.level)"
        }
        if isReadyToCollect(building: building, now: now) {
            return "Ready to collect"
        }
        if building.isProducing == true, let productionEndsAt = building.productionEndsAt {
            return formattedTimeRemaining(until: productionEndsAt, now: now)
        }
        return "Level \(building.level)"
    }

    /// Input required to start production (e.g. "2 Fuel Cells" for extractors).
    func productionInputHint(for building: Building) -> String? {
        let isExtractor = building.type == .mine || building.type == .rig || building.type == .quarry
        if isExtractor {
            let n = Int(ProductionService.fuelRequiredPerCycle)
            return n == 1 ? "1 Fuel Cell" : "\(n) Fuel Cells"
        }
        return nil
    }

    func formattedTimeRemaining(until endDate: Date, now: Date) -> String {
        let remainingSeconds = max(0, Int(ceil(endDate.timeIntervalSince(now))))
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func prospectingLabel(for resourceType: ResourceType) -> String {
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

    func buildingFamilyLabel(for building: Building) -> String {
        if let resourceType = building.resourceType {
            switch resourceType {
            case .gold: return "Gold"
            case .silver: return "Silver"
            case .diamond: return "Diamond"
            case .oil: return "Oil"
            case .coal: return "Coal"
            case .iron: return "Iron"
            case .quarry, .sandQuarry, .stoneQuarry, .gravelQuarry: return "Quarry"
            default: return building.type.rawValue
            }
        }
        return building.type.rawValue
    }

    func buildingAssetName(for building: Building) -> String {
        let lowercasedName = building.name.lowercased()

        if lowercasedName.contains("stone quarry") { return "icon_stone_quarry" }
        if lowercasedName.contains("sand quarry") { return "icon_sand_quarry" }
        if lowercasedName.contains("gravel quarry") { return "icon_gravel_quarry" }
        if lowercasedName.contains("gold refinery") { return "icon_gold_refinery" }
        if lowercasedName.contains("silver refinery") { return "icon_silver_refinery" }
        if lowercasedName.contains("diamond refinery") { return "icon_diamond_refinery" }
        if lowercasedName.contains("coal refinery") { return "icon_coal_refinery" }
        if lowercasedName.contains("oil refinery") { return "icon_oil_refinery" }
        if lowercasedName.contains("fuel processing plant") { return "icon_fuel_processing_plant" }
        if lowercasedName.contains("construction materials") { return "icon_construction_materials_factory" }
        if lowercasedName.contains("materials depot") { return "icon_materials_depot" }
        if lowercasedName.contains("tech plant") { return "icon_tech_plant" }
        if lowercasedName.contains("fabrication plant") { return "icon_fabrication_plant" }
        if lowercasedName.contains("iron bar factory") { return "icon_iron_bar_factory" }
        if lowercasedName.contains("diamond processing plant") { return "icon_diamond_processing_plant" }
        if lowercasedName.contains("silver processing plant") { return "icon_silver_processing_plant" }
        if lowercasedName.contains("oil rig") { return "icon_oil_rig" }
        if lowercasedName.contains("coal mine") { return "icon_raw_coal_mine" }
        if lowercasedName.contains("silver mine") { return "icon_raw_silver_mine" }
        if lowercasedName.contains("diamond mine") { return "icon_raw_diamond_mine" }
        if lowercasedName.contains("gold mine") { return "icon_gold_refinery" }
        if lowercasedName.contains("iron mine") { return "icon_iron_bar_factory" }

        return "icon_blueprint"
    }

    func prospectingAssetName(for job: ProspectingJob) -> String {
        switch job.resourceType {
        case .gold: return "icon_gold_refinery"
        case .silver: return "icon_raw_silver_mine"
        case .diamond: return "icon_raw_diamond_mine"
        case .oil: return "icon_oil_rig"
        case .coal: return "icon_raw_coal_mine"
        case .iron: return "icon_iron_bar_factory"
        case .quarry, .stoneQuarry: return "icon_stone_quarry"
        case .sandQuarry: return "icon_sand_quarry"
        case .gravelQuarry: return "icon_gravel_quarry"
        default: return "icon_blueprint"
        }
    }
}
