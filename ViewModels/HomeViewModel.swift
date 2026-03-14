//
//  HomeViewModel.swift
//  Boardroom Tycoon
//
//  MVVM: Presentation logic and state for the Home screen.
//

import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    let userID: String

    @Published private(set) var prospectingJobs: [ProspectingJob] = []
    @Published private(set) var isLoadingProspecting = true
    @Published private(set) var prospectingErrorMessage: String?

    private let prospectingService = ProspectingService()
    private let mineMarketService = MineMarketService()

    init(userID: String) {
        self.userID = userID
    }

    func loadData() {
        mineMarketService.settleExpiredMineListings { [weak self] _ in
            self?.loadProspectingJobs()
        }
    }

    func loadProspectingJobs() {
        prospectingService.fetchProspectingJobs(for: userID) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let jobs):
                    self.prospectingJobs = jobs
                    self.isLoadingProspecting = false
                    self.prospectingErrorMessage = nil
                case .failure(let error):
                    self.prospectingErrorMessage = error.localizedDescription
                    self.isLoadingProspecting = false
                }
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
