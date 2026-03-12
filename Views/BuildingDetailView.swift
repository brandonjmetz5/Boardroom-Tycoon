//
//  BuildingDetailView.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/12/26.
//

import SwiftUI

struct BuildingDetailView: View {
    let building: Building

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
                        Text("Mine Details")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Resource: \(building.resourceType?.rawValue ?? "Unknown")")
                            Text("Abundance: \(building.abundance ?? 0)")
                            Text("Stability: \(building.stability ?? 0)")
                            Text("Starter Mine: \((building.isStarterMine ?? false) ? "Yes" : "No")")
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
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
}

#Preview {
    NavigationStack {
        BuildingDetailView(
            building: Building(
                id: "building-starter-gold-mine",
                name: "Starter Gold Mine",
                type: .mine,
                level: 1,
                capacity: 1,
                resourceType: .gold,
                abundance: 50,
                stability: 55,
                isStarterMine: true
            )
        )
    }
}
