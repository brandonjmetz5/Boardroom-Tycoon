//
//  ProfileView.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/11/26.
//

import SwiftUI

struct ProfileView: View {
    let userID: String

    @StateObject private var viewModel: ProfileViewModel

    init(userID: String) {
        self.userID = userID
        _viewModel = StateObject(wrappedValue: ProfileViewModel(userID: userID))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.isLoading {
                ProgressView("Loading profile...")
                    .controlSize(.large)
            } else if let errorMessage = viewModel.errorMessage {
                Text("Failed to load profile")
                    .font(.headline)

                Text(errorMessage)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.leading)
            } else if let profile = viewModel.profile {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Player ID: \(profile.id)")
                    Text("Cash: $\(profile.cash, specifier: "%.2f")")
                    Text("Level: \(profile.level)")
                    Text("XP: \(profile.xp)")
                    Text("Building Slots: \(profile.buildingSlotCount)")
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
            viewModel.loadProfile()
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView(userID: "demo-user-id-12345")
    }
}
