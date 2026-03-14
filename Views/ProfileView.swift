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
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            Group {
                if viewModel.isLoading {
                    ProgressView("Loading profile...")
                        .controlSize(.large)
                        .tint(.white)
                        .foregroundStyle(AppTheme.textPrimary)
                } else if let errorMessage = viewModel.errorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Failed to load profile")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(errorMessage)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(AppTheme.textError)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(AppTheme.horizontalPadding)
                } else if let profile = viewModel.profile {
                    ScrollView {
                        VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                            profileCard(profile: profile)
                        }
                        .padding(.horizontal, AppTheme.horizontalPadding)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                    }
                } else {
                    Text("No profile found.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding()
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Profile")
                    .font(AppTheme.titleMedium())
                    .foregroundStyle(AppTheme.textPrimary)
            }
        }
        .onAppear {
            viewModel.loadProfile()
        }
    }

    private func profileCard(profile: PlayerProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Player")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.textMuted)

            profileRow("Player ID", profile.id)
            profileRow("Cash", String(format: "$%.2f", profile.cash))
            profileRow("Level", "\(profile.level)")
            profileRow("XP", "\(profile.xp)")
            profileRow("Building Slots", "\(profile.buildingSlotCount)")
            profileRow("Starter Mine Claimed", profile.starterMineClaimed ? "Yes" : "No")
            profileRow("Created", profile.createdAt.formatted(date: .abbreviated, time: .shortened))
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    private func profileRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.textTertiary)
                .frame(width: 140, alignment: .leading)
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        ProfileView(userID: "demo-user-id-12345")
    }
}
