//
//  ProfileViewModel.swift
//  Boardroom Tycoon
//
//  MVVM: Presentation logic and state for the Profile screen.
//

import Foundation
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    let userID: String

    @Published private(set) var profile: PlayerProfile?
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?

    private let playerProfileService = PlayerProfileService()

    init(userID: String) {
        self.userID = userID
    }

    func loadProfile() {
        playerProfileService.fetchPlayerProfile(for: userID) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let loadedProfile):
                    self.profile = loadedProfile
                    self.isLoading = false
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}
