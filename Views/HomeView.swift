//
//  HomeView.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/11/26.
//

import SwiftUI
import Combine

struct HomeView: View {
    let userID: String

    @State private var prospectingJobs: [ProspectingJob] = []
    @State private var isLoadingProspecting = true
    @State private var prospectingErrorMessage: String?

    private let prospectingService = ProspectingService()
    private let mineMarketService = MineMarketService()

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Boardroom Tycoon")
                        .font(.largeTitle)
                        .bold()

                    Text("Welcome to your boardroom.")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Player ID")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(userID)
                        .font(.caption)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Prospecting")
                        .font(.headline)

                    if isLoadingProspecting {
                        ProgressView("Loading prospecting jobs...")
                            .controlSize(.small)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                    } else if let prospectingErrorMessage {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Failed to load prospecting jobs")
                                .font(.subheadline)
                                .bold()

                            Text(prospectingErrorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    } else if let activeJob = prospectingJobs.first(where: { !$0.isComplete }) {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Resource: \(prospectingLabel(for: activeJob.resourceType))")

                                if activeJob.isRevealed {
                                    Text("Status: Result Revealed")
                                        .bold()
                                } else if activeJob.endsAt <= context.date {
                                    Text("Status: Ready to Reveal")
                                        .bold()
                                } else {
                                    Text("Time Remaining: \(formattedTimeRemaining(until: activeJob.endsAt, now: context.date))")
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("No Active Prospecting Job")
                                .font(.subheadline)
                                .bold()

                            Text("Start prospecting from an empty building slot.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }
                }

                LazyVGrid(columns: columns, spacing: 16) {
                    DashboardCard(
                        title: "Operations",
                        systemImage: "gearshape",
                        destination: OperationsView(userID: userID)
                    )

                    DashboardCard(
                        title: "Market",
                        systemImage: "cart",
                        destination: MarketView(userID: userID)
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
            .padding()
        }
        .navigationTitle("Home")
        .onAppear {
            mineMarketService.settleExpiredMineListings { _ in }
            loadProspectingJobs()
        }
    }

    private func loadProspectingJobs() {
        prospectingService.fetchProspectingJobs(for: userID) { result in
            DispatchQueue.main.async {
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

    private func formattedTimeRemaining(until endDate: Date, now: Date) -> String {
        let remainingSeconds = max(0, Int(ceil(endDate.timeIntervalSince(now))))
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func prospectingLabel(for resourceType: ResourceType) -> String {
        switch resourceType {
        case .gold:
            return "Gold Mine"
        case .silver:
            return "Silver Mine"
        case .diamond:
            return "Diamond Mine"
        case .oil:
            return "Oil Rig"
        case .coal:
            return "Coal Mine"
        case .iron:
            return "Iron Mine"
        default:
            return resourceType.rawValue
        }
    }
}

#Preview {
    NavigationStack {
        HomeView(userID: "demo-user-id-12345")
    }
}
