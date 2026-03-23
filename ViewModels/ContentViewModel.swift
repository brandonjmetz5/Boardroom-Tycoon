//
//  ContentViewModel.swift
//  Boardroom Tycoon
//
//  MVVM: Presentation logic and state for the root Content (auth) screen.
//

import Foundation
import Combine
import FirebaseAuth

@MainActor
final class ContentViewModel: ObservableObject {
    @Published private(set) var userID: String?
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?

    private let playerProfileService = PlayerProfileService()
    private let inventoryService = InventoryService()
    private let buildingService = BuildingService()

    func signInAnonymouslyIfNeeded() {
        if let currentUser = Auth.auth().currentUser {
            createPlayerProfile(for: currentUser.uid)
            return
        }

        Auth.auth().signInAnonymously { [weak self] authResult, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    return
                }

                if let uid = authResult?.user.uid {
                    self.createPlayerProfile(for: uid)
                } else {
                    self.errorMessage = "Failed to retrieve user ID."
                    self.isLoading = false
                }
            }
        }
    }

    private func createPlayerProfile(for uid: String) {
        let profile = PlayerProfile(
            id: uid,
            cash: 90_000,
            level: 1,
            xp: 0,
            buildingSlotCount: 2,
            starterMineClaimed: false,
            researchPoints: 0,
            createdAt: Date()
        
        )

        playerProfileService.createPlayerProfileIfNeeded(for: profile) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success:
                    self.buildingService.grantStarterMineIfNeeded(for: uid) { [weak self] starterMineResult in
                        DispatchQueue.main.async {
                            guard let self else { return }
                            switch starterMineResult {
                            case .success:
                                self.inventoryService.createStarterInventoryIfNeeded(for: uid) { [weak self] inventoryResult in
                                    DispatchQueue.main.async {
                                        guard let self else { return }
                                        switch inventoryResult {
                                        case .success:
                                            self.userID = uid
                                            self.isLoading = false
                                        case .failure(let error):
                                            self.errorMessage = error.localizedDescription
                                            self.isLoading = false
                                        }
                                    }
                                }
                            case .failure(let error):
                                self.errorMessage = error.localizedDescription
                                self.isLoading = false
                            }
                        }
                    }
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}
