//
//  BuildingDetailView.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/12/26.
//

import SwiftUI
import Combine

struct BuildingDetailView: View {
    let userID: String
    let building: Building

    @State private var currentBuilding: Building
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var now = Date()

    private let productionService = ProductionService()
    private let buildingService = BuildingService()

    init(userID: String, building: Building) {
        self.userID = userID
        self.building = building
        _currentBuilding = State(initialValue: building)
    }

    let mockMachines: [Machine] = [
        Machine(
            id: "machine-001",
            name: "Refinery Machine",
            level: 1,
            efficiencyBonus: 0.0
        ),
        Machine(
            id: "machine-002",
            name: "Refinery Machine",
            level: 2,
            efficiencyBonus: 0.05
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Type: \(currentBuilding.type.rawValue)")
                    Text("Level: \(currentBuilding.level)")
                    Text("Capacity: \(currentBuilding.capacity)")
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)

                if currentBuilding.type == .mine || currentBuilding.type == .rig || currentBuilding.type == .quarry {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Mine Details")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Resource: \(currentBuilding.resourceType?.rawValue ?? "Unknown")")
                            Text("Abundance: \(currentBuilding.abundance ?? 0)")
                            Text("Stability: \(currentBuilding.stability ?? 0)")
                            Text("Starter Mine: \((currentBuilding.isStarterMine ?? false) ? "Yes" : "No")")
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Production")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Producing: \((currentBuilding.isProducing ?? false) ? "Yes" : "No")")

                            if currentBuilding.isProducing == true,
                               let productionEndsAt = currentBuilding.productionEndsAt {
                                Text("Time Remaining: \(formattedTimeRemaining(until: productionEndsAt))")
                            }

                            if let pendingOutputQuantity = currentBuilding.pendingOutputQuantity,
                               pendingOutputQuantity > 0 {
                                Text("Pending Output: \(Int(pendingOutputQuantity))")
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)

                        if let errorMessage {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                        }

                        if isWorking {
                            ProgressView()
                        } else if currentBuilding.isProducing == true {
                            if let productionEndsAt = currentBuilding.productionEndsAt,
                               productionEndsAt <= now {
                                Button("Collect Output") {
                                    collectProduction()
                                }
                                .buttonStyle(.borderedProminent)
                            } else {
                                Text("Production is currently running.")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Button("Start Production") {
                                startProduction()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Machines")
                            .font(.headline)

                        ForEach(mockMachines.prefix(currentBuilding.capacity)) { machine in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(machine.name)
                                    .font(.headline)

                                Text("Level: \(machine.level)")
                                Text("Efficiency Bonus: \(Int(machine.efficiencyBonus * 100))%")
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle(currentBuilding.name)
        .onAppear {
            refreshBuilding()
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { currentTime in
            now = currentTime
        }
    }

    private func refreshBuilding() {
        buildingService.fetchBuildings(for: userID) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let buildings):
                    if let updated = buildings.first(where: { $0.id == currentBuilding.id }) {
                        self.currentBuilding = updated
                    }
                case .failure:
                    break
                }
            }
        }
    }

    private func startProduction() {
        isWorking = true
        errorMessage = nil

        productionService.startProduction(for: userID, buildingID: currentBuilding.id) { result in
            DispatchQueue.main.async {
                self.isWorking = false

                switch result {
                case .success:
                    refreshBuilding()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func collectProduction() {
        isWorking = true
        errorMessage = nil

        productionService.collectProduction(for: userID, buildingID: currentBuilding.id) { result in
            DispatchQueue.main.async {
                self.isWorking = false

                switch result {
                case .success:
                    refreshBuilding()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func formattedTimeRemaining(until endDate: Date) -> String {
        let remainingSeconds = max(0, Int(endDate.timeIntervalSince(now)))
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    NavigationStack {
        BuildingDetailView(
            userID: "demo-user-id-12345",
            building: Building(
                id: "building-starter-gold-mine",
                name: "Starter Gold Mine",
                type: .mine,
                level: 1,
                capacity: 1,
                resourceType: .gold,
                abundance: 50,
                stability: 55,
                isStarterMine: true,
                isProducing: false,
                productionStartedAt: nil,
                productionEndsAt: nil,
                pendingOutputQuantity: nil
            )
        )
    }
}
