//
//  HomeView.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/11/26.
//

import SwiftUI

struct HomeView: View {
    let userID: String

    @StateObject private var viewModel: HomeViewModel

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    init(userID: String) {
        self.userID = userID
        _viewModel = StateObject(wrappedValue: HomeViewModel(userID: userID))
    }

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                    headerSection
                    playerIDSection
                    prospectingSection
                    dashboardGridSection
                }
                .padding(.horizontal, AppTheme.horizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Home")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
            }
        }
        .onAppear {
            viewModel.loadData()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Boardroom Tycoon")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Text("Welcome to your boardroom.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private var playerIDSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Player ID")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.textMuted)

            Text(userID)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .themedPill()
        }
    }

    private var prospectingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prospecting")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            if viewModel.isLoadingProspecting {
                ProgressView("Loading prospecting jobs...")
                    .controlSize(.small)
                    .tint(.white)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(AppTheme.cardPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .themedCard()
            } else if let prospectingErrorMessage = viewModel.prospectingErrorMessage {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Failed to load prospecting jobs")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(prospectingErrorMessage)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AppTheme.textError)
                }
                .padding(AppTheme.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .themedCard()
            } else if let activeJob = viewModel.activeProspectingJob {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Resource: \(viewModel.prospectingLabel(for: activeJob.resourceType))")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)

                        if activeJob.isRevealed {
                            Text("Status: Result Revealed")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.chipReady)
                        } else if activeJob.endsAt <= context.date {
                            Text("Status: Ready to Reveal")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.chipReady)
                        } else {
                            Text("Time Remaining: \(viewModel.formattedTimeRemaining(until: activeJob.endsAt, now: context.date))")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    .padding(AppTheme.cardPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .themedCard()
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No Active Prospecting Job")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Start prospecting from an empty building slot.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .padding(AppTheme.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .themedCard()
            }
        }
    }

    private var dashboardGridSection: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            DashboardCard(
                title: "Operations",
                systemImage: "gearshape",
                destination: OperationsView(userID: userID)
            )
            DashboardCard(
                title: "Market",
                systemImage: "cart",
                destination: MarketHubView(userID: userID)
            )
            DashboardCard(
                title: "Stocks",
                systemImage: "chart.line.uptrend.xyaxis",
                destination: StocksView()
            )
            DashboardCard(
                title: "Inventory",
                systemImage: "shippingbox",
                destination: InventoryView(userID: userID)
            )
            DashboardCard(
                title: "Profile",
                systemImage: "person",
                destination: ProfileView(userID: userID)
            )
        }
    }
}

#Preview {
    NavigationStack {
        HomeView(userID: "demo-user-id-12345")
    }
}
