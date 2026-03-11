//
//  ContentView.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/11/26.
//

import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @State private var userID: String?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let playerProfileService = PlayerProfileService()
    private let inventoryService = InventoryService()

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Signing in...")
                    .controlSize(.large)
            } else if let errorMessage {
                VStack(spacing: 12) {
                    Text("Authentication Failed")
                        .font(.title2)
                        .bold()

                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
            } else if let userID {
                NavigationStack {
                    HomeView(userID: userID)
                }
            } else {
                Text("No user found.")
                    .padding()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                signInAnonymouslyIfNeeded()
            }
        }
        // .onAppear {
        //     signInAnonymouslyIfNeeded()
        // }

        /// This loading sign in spinner was added for visual testing.
        /// I wanted to make sure that the user knows that app isnt slow to launch
        /// but simply signing in. Can later add some sort of game logo / UI movement
        /// visual to mask the authentication process.
    }

    private func signInAnonymouslyIfNeeded() {
        if let currentUser = Auth.auth().currentUser {
            createPlayerProfile(for: currentUser.uid)
            return
        }

        Auth.auth().signInAnonymously { authResult, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    return
                }

                if let uid = authResult?.user.uid {
                    createPlayerProfile(for: uid)
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
            cash: 10000,
            level: 1,
            starterMineClaimed: false,
            createdAt: Date()
        )

        playerProfileService.createPlayerProfileIfNeeded(for: profile) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    inventoryService.createStarterInventoryIfNeeded(for: uid) { inventoryResult in
                        DispatchQueue.main.async {
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
    }
}

#Preview {
    ContentView()
}
