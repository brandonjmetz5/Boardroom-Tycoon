//
//  HomeView.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/11/26.
//

import SwiftUI

struct HomeView: View {
    let userID: String

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    let sampleProspectingJob = ProspectingJob(
        id: "prospecting-001",
        resourceType: .gold,
        startedAt: Date().addingTimeInterval(-3600),
        endsAt: Date().addingTimeInterval(14400),
        isComplete: false
    )

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
                    Text("Active Prospecting Job")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Resource: \(sampleProspectingJob.resourceType.rawValue)")
                        Text("Complete: \(sampleProspectingJob.isComplete ? "Yes" : "No")")
                        Text("Ends: \(sampleProspectingJob.endsAt.formatted(date: .abbreviated, time: .shortened))")
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }

                LazyVGrid(columns: columns, spacing: 16) {
                    DashboardCard(
                        title: "Operations",
                        systemImage: "gearshape",
                        destination: OperationsView()
                    )

                    DashboardCard(
                        title: "Market",
                        systemImage: "cart",
                        destination: MarketView()
                    )

                    DashboardCard(
                        title: "Stocks",
                        systemImage: "chart.line.uptrend.xyaxis",
                        destination: StocksView()
                    )

                    DashboardCard(
                        title: "Inventory",
                        systemImage: "shippingbox",
                        destination: InventoryView()
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
    }
}

#Preview {
    NavigationStack {
        HomeView(userID: "demo-user-id-12345")
    }
}
