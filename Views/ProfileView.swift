//
//  ProfileView.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/11/26.
//

import SwiftUI

struct ProfileView: View {
    let userID: String
    
    @State private var profile: PlayerProfile?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    private let playerProfileService = PlayerProfileService()
    
    var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                if isLoading {
                    ProgressView("Loading profile...")
                        .controlSize(.large)
                } else if let errorMessage {
                    Text("Failed to load profile")
                        .font(.headline)

                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.leading)
                } else if let profile {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Player ID: \(profile.id)")
                        Text("Cash: $\(profile.cash, specifier: "%.2f")")
                        Text("Level: \(profile.level)")
                        Text("Starter Mine Claimed: \(profile.starterMineClaimed ? "Yes" : "No")")
                        Text("Created At: \(profile.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)

                    Spacer()
                } else {
                    Text("No profile found.")
                }
            }
            .padding()
            .onAppear {
                loadProfile()
            }
        }

        private func loadProfile() {
            playerProfileService.fetchPlayerProfile(for: userID) { result in
                DispatchQueue.main.async {
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

    #Preview {
        NavigationStack {
            ProfileView(userID: "demo-user-id-12345")
        }
    }
