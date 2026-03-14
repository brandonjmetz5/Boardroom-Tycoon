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
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    init(userID: String) {
        self.userID = userID
        _viewModel = StateObject(wrappedValue: HomeViewModel(userID: userID))
    }

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

                    if viewModel.isLoadingProspecting {
                        ProgressView("Loading prospecting jobs...")
                            .controlSize(.small)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                    } else if let prospectingErrorMessage = viewModel.prospectingErrorMessage {
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
                    } else if let activeJob = viewModel.activeProspectingJob {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Resource: \(viewModel.prospectingLabel(for: activeJob.resourceType))")

                                if activeJob.isRevealed {
                                    Text("Status: Result Revealed")
                                        .bold()
                                } else if activeJob.endsAt <= context.date {
                                    Text("Status: Ready to Reveal")
                                        .bold()
                                } else {
                                    Text("Time Remaining: \(viewModel.formattedTimeRemaining(until: activeJob.endsAt, now: context.date))")
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
            viewModel.loadData()
        }
    }
}

#Preview {
    NavigationStack {
        HomeView(userID: "demo-user-id-12345")
    }
}
