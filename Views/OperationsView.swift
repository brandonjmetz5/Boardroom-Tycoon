//
//  OperationsView.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/11/26.
//

import SwiftUI

struct OperationsView: View {
    let userID: String

    @State private var buildings: [Building] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isPurchasingStarterMine = false

    private let buildingService = BuildingService()

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading buildings...")
                    .controlSize(.large)
            } else if let errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Failed to load buildings")
                        .font(.headline)

                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
                .padding()
            } else if buildings.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("No Buildings Yet")
                        .font(.headline)

                    Text("Use your starter cash to purchase your first building.")
                        .foregroundStyle(.secondary)

                    Button {
                        purchaseStarterMine()
                    } label: {
                        if isPurchasingStarterMine {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Buy Starter Mine")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isPurchasingStarterMine)
                }
                .padding()
            } else {
                List(buildings) { building in
                    NavigationLink(destination: BuildingDetailView(building: building)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(building.name)
                                .font(.headline)

                            Text("Type: \(building.type.rawValue)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text("Level: \(building.level)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text("Capacity: \(building.capacity)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .onAppear {
            loadBuildings()
        }
    }

    private func loadBuildings() {
        buildingService.fetchBuildings(for: userID) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let loadedBuildings):
                    self.buildings = loadedBuildings
                    self.isLoading = false
                    self.errorMessage = nil
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func purchaseStarterMine() {
        isPurchasingStarterMine = true
        errorMessage = nil

        buildingService.purchaseStarterMine(for: userID) { result in
            DispatchQueue.main.async {
                self.isPurchasingStarterMine = false

                switch result {
                case .success:
                    loadBuildings()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        OperationsView(userID: "demo-user-id-12345")
    }
}
