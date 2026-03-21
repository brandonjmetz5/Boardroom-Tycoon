//
//  ProfileView.swift
//  Boardroom Tycoon
//
//  Executive profile command console.
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
            AppTheme.background.ignoresSafeArea()
            LinearGradient(
                colors: [AppTheme.surface.opacity(0.12), Color.clear, AppTheme.surface.opacity(0.10)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Group {
                if viewModel.isLoading {
                    VStack(spacing: 14) {
                        ProgressView().scaleEffect(1.15).tint(AppTheme.accent)
                        Text("Synchronizing executive profile...")
                            .font(AppTheme.caption())
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                } else if let errorMessage = viewModel.errorMessage {
                    ProfileRail(title: "System Fault", systemImage: "exclamationmark.triangle.fill", tone: .priority) {
                        Text(errorMessage)
                            .font(AppTheme.caption())
                            .foregroundStyle(AppTheme.textError)
                    }
                    .padding(.horizontal, AppTheme.horizontalPadding)
                } else if let profile = viewModel.profile {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            identityRail(profile)
                            progressionRail(profile)
                            financeRail(profile)
                            accountRail(profile)
                            commandRail
                        }
                        .padding(.horizontal, AppTheme.horizontalPadding)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                    }
                } else {
                    ProfileRail(title: "Profile", systemImage: "person.fill") {
                        Text("No profile found.")
                            .font(AppTheme.caption())
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(.horizontal, AppTheme.horizontalPadding)
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
        .onAppear { viewModel.loadProfile() }
    }

    private func identityRail(_ profile: PlayerProfile) -> some View {
        ProfileRail(title: "Executive Identity", systemImage: "person.crop.circle.fill", tone: .priority) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.surfaceAlt.opacity(0.62))
                                .frame(width: 44, height: 44)
                            Image(systemName: "person.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(AppTheme.accent)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Chief Executive Operator")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("ID \(profile.id)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                    }
                    Spacer()
                    statusPill(title: profile.starterMineClaimed ? "STARTER ASSET CLAIMED" : "STARTER ASSET PENDING", color: profile.starterMineClaimed ? AppTheme.chipReady : AppTheme.chipProducing)
                }

                HStack(spacing: 10) {
                    metricTile("LEVEL", "\(profile.level)", AppTheme.accent)
                    metricTile("XP", "\(profile.xp)", AppTheme.chipAvailable)
                    metricTile("R&D", "\(profile.researchPoints)", AppTheme.chipListed)
                }
            }
        }
    }

    private func progressionRail(_ profile: PlayerProfile) -> some View {
        ProfileRail(title: "Progression Matrix", systemImage: "flag.fill") {
            VStack(alignment: .leading, spacing: 8) {
                telemetryRow("LEVEL", "\(profile.level)")
                telemetryRow("XP", "\(profile.xp)")
                telemetryRow("BUILDING SLOTS", "\(profile.buildingSlotCount)")
                telemetryRow("RESEARCH POINTS", "\(profile.researchPoints)")
            }
        }
    }

    private func financeRail(_ profile: PlayerProfile) -> some View {
        ProfileRail(title: "Treasury Ledger", systemImage: "banknote.fill") {
            VStack(alignment: .leading, spacing: 8) {
                telemetryRow("LIQUID CASH", String(format: "$%.2f", profile.cash), tint: AppTheme.accent)
                telemetryRow("SLOT CAPACITY", "\(profile.buildingSlotCount)", tint: AppTheme.chipProspecting)
                telemetryRow(
                    "CASH / SLOT",
                    String(format: "$%.2f", profile.cash / max(1, Double(profile.buildingSlotCount))),
                    tint: AppTheme.chipReady
                )
            }
        }
    }

    private func accountRail(_ profile: PlayerProfile) -> some View {
        ProfileRail(title: "Account Telemetry", systemImage: "person.text.rectangle.fill") {
            VStack(alignment: .leading, spacing: 8) {
                telemetryRow("USER ID", profile.id)
                telemetryRow("CREATED", profile.createdAt.formatted(date: .abbreviated, time: .shortened))
                telemetryRow("STARTER MINE", profile.starterMineClaimed ? "CLAIMED" : "NOT CLAIMED", tint: profile.starterMineClaimed ? AppTheme.chipReady : AppTheme.chipProducing)
            }
        }
    }

    private var commandRail: some View {
        ProfileRail(title: "Command Actions", systemImage: "bolt.fill") {
            VStack(spacing: 8) {
                actionRow("Refresh Profile Data", icon: "arrow.clockwise")
                    .onTapGesture { viewModel.loadProfile() }
                actionRow("Profile sync source: Firestore", icon: "externaldrive.fill.badge.checkmark")
                actionRow("Profile build: Executive Console", icon: "checkmark.seal.fill")
            }
        }
    }

    private func metricTile(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.textTertiary)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.surfaceAlt.opacity(0.58)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border.opacity(0.95), lineWidth: 1))
    }

    private func telemetryRow(_ label: String, _ value: String, tint: Color = AppTheme.textPrimary) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.textTertiary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(tint)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.surfaceAlt.opacity(0.55)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border.opacity(0.95), lineWidth: 1))
    }

    private func statusPill(title: String, color: Color) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.15)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.45), lineWidth: 1))
    }

    private func actionRow(_ title: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.accent)
            Text(title)
                .font(AppTheme.captionMedium())
                .foregroundStyle(AppTheme.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.surfaceAlt.opacity(0.55)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border.opacity(0.95), lineWidth: 1))
    }
}

private enum ProfileRailTone {
    case normal
    case priority
}

private struct ProfileRail<Content: View>: View {
    let title: String
    let systemImage: String
    var tone: ProfileRailTone
    private let content: Content

    init(
        title: String,
        systemImage: String,
        tone: ProfileRailTone = .normal,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tone = tone
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(tone == .priority ? AppTheme.accent : AppTheme.textSecondary)
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)
                Rectangle().fill(AppTheme.border).frame(height: 1)
            }
            content
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.surface.opacity(0.82)))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(tone == .priority ? AppTheme.accent.opacity(0.32) : AppTheme.border.opacity(0.95), lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack {
        ProfileView(userID: "demo-user-id-12345")
    }
}
