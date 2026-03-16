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
    let building: Building

    @Published private(set) var profile: PlayerProfile?
    @Published private(set) var items: [Item] = []
    @Published private(set) var qualities: [ResourceQuality] = []

    @Published private(set) var isLoading = true
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?

    /// Number of research points the player wants to apply when upgrading a resource.
    @Published var pointsToApplyText: String = "50"

    private let playerProfileService = PlayerProfileService()
    private let itemService = ItemService()
    private let qualityService = ResourceQualityService()
    private let productionService = ProductionService()

    init(userID: String, building: Building) {
        self.userID = userID
        self.building = building
    }

    func loadData() {
        isLoading = true
        errorMessage = nil

        let group = DispatchGroup()

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
                if case .success(let items) = result {
                    // Only show resources (raw/refined/building materials) for now.
                    self.items = items.sorted { $0.name < $1.name }
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

    func startResearchCycle() {
        isWorking = true
        errorMessage = nil
        productionService.startResearchCycle(for: userID, buildingID: building.id) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isWorking = false
                switch result {
                case .success:
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
        productionService.collectProduction(for: userID, buildingID: building.id) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isWorking = false
                switch result {
                case .success:
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

    func applyResearchPoints(to item: Item) {
        guard let profile else {
            errorMessage = "Profile not loaded."
            return
        }
        let available = profile.researchPoints
        let amount = Int(pointsToApplyText) ?? 0
        if amount <= 0 {
            errorMessage = "Enter a positive number of points to apply."
            return
        }
        if amount > available {
            errorMessage = "Not enough research points. You have \(available)."
            return
        }

        isWorking = true
        errorMessage = nil
        qualityService.addResearchPoints(for: userID, itemID: item.id, points: amount) { [weak self] result in
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

