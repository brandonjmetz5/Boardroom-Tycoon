//
//  BuildingDetailView.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/12/26.
//

import SwiftUI

struct BuildingDetailView: View {
    let building: Building

    let mockMines: [Mine] = [
        Mine(
            id: "mine-001",
            buildingID: "building-gold-mine",
            resourceType: .gold,
            level: 1,
            abundance: 65,
            stability: 72,
            isStarterMine: true
        ),
        Mine(
            id: "mine-002",
            buildingID: "building-gold-mine",
            resourceType: .gold,
            level: 1,
            abundance: 81,
            stability: 60,
            isStarterMine: false
        )
    ]

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
                    Text("Type: \(building.type.rawValue)")
                    Text("Level: \(building.level)")
                    Text("Capacity: \(building.capacity)")
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)

                if building.type == .mine || building.type == .rig || building.type == .quarry {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Mines")
                            .font(.headline)

                        ForEach(matchingMines.prefix(building.capacity)) { mine in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(mine.resourceType.rawValue) Mine")
                                    .font(.headline)

                                Text("Level: \(mine.level)")
                                Text("Abundance: \(mine.abundance)")
                                Text("Stability: \(mine.stability)")
                                Text("Starter Mine: \(mine.isStarterMine ? "Yes" : "No")")
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Machines")
                            .font(.headline)

                        ForEach(mockMachines.prefix(building.capacity)) { machine in
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
        .navigationTitle(building.name)
    }

    private var matchingMines: [Mine] {
        mockMines.filter { $0.buildingID == building.id }
    }
}

#Preview {
    NavigationStack {
        BuildingDetailView(
            building: Building(
                id: "building-gold-mine",
                name: "Gold Mine",
                type: .mine,
                level: 1,
                capacity: 2
            )
        )
    }
}
