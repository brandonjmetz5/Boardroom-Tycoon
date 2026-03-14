//
//  HomeViewModel.swift
//  Boardroom Tycoon
//
//  MVVM: Presentation logic and state for the Home screen.
//

import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    let userID: String

    @Published private(set) var profile: PlayerProfile?
    @Published private(set) var buildings: [Building] = []
    @Published private(set) var prospectingJobs: [ProspectingJob] = []
    @Published private(set) var isLoading = true
    @Published private(set) var isLoadingProspecting = true
    @Published private(set) var prospectingErrorMessage: String?
    @Published private(set) var profileErrorMessage: String?

    private let playerProfileService = PlayerProfileService()
    private let buildingService = BuildingService()
    private let prospectingService = ProspectingService()
    private let mineMarketService = MineMarketService()

    init(userID: String) {
        self.userID = userID
    }

    func loadData() {
        isLoading = true
        profileErrorMessage = nil
        prospectingErrorMessage = nil
        mineMarketService.settleExpiredMineListings { [weak self] _ in
            self?.loadProfileAndProspecting()
        }
    }

    private func loadProfileAndProspecting() {
        let group = DispatchGroup()

        group.enter()
        playerProfileService.fetchPlayerProfile(for: userID) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let p): self.profile = p
                case .failure(let e): self.profileErrorMessage = e.localizedDescription
                }
                group.leave()
            }
        }

        group.enter()
        buildingService.fetchBuildings(for: userID) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let list): self.buildings = list
                case .failure: break
                }
                group.leave()
            }
        }

        group.enter()
        loadProspectingJobs { [weak self] in
            self?.isLoadingProspecting = false
            group.leave()
        }

        group.notify(queue: .main) { [weak self] in
            self?.isLoading = false
        }
    }

    private func isReadyToCollect(building: Building, now: Date) -> Bool {
        guard building.isProducing == true, let endsAt = building.productionEndsAt else { return false }
        return endsAt <= now
    }

    var producingCount: Int {
        let now = Date()
        return buildings.filter { b in
            b.isProducing == true && !isReadyToCollect(building: b, now: now)
        }.count
    }

    var readyCount: Int {
        buildings.filter { isReadyToCollect(building: $0, now: Date()) }.count
    }

    var listedCount: Int {
        buildings.filter { $0.isListedOnMarket == true }.count
    }

    var usedSlotsCount: Int {
        buildings.count + prospectingJobs.filter { !$0.isComplete }.count
    }

    var totalSlotsCount: Int {
        profile?.buildingSlotCount ?? max(usedSlotsCount, 1)
    }

    private func loadProspectingJobs(completion: @escaping () -> Void) {
        prospectingService.fetchProspectingJobs(for: userID) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let jobs):
                    self.prospectingJobs = jobs
                    self.prospectingErrorMessage = nil
                case .failure(let error):
                    self.prospectingErrorMessage = error.localizedDescription
                }
                completion()
            }
        }
    }

    var activeProspectingJob: ProspectingJob? {
        prospectingJobs.first(where: { !$0.isComplete })
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
        default: return resourceType.rawValue
        }
    }
}
