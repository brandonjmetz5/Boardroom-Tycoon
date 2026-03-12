//
//  OperationDetailView.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/11/26.
//

import SwiftUI

struct OperationDetailView: View {
    let operation: Operation

    let mockMines: [Mine] = [
        Mine(
            id: "mine-001",
            buildingID: "op-gold-production",
            resourceType: .gold,
            level: 1,
            abundance: 65,
            stability: 72,
            isStarterMine: true
        ),
        Mine(
            id: "mine-002",
            buildingID: "op-gold-production",
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
                    Text("Type: \(operation.type.rawValue)")
                    Text("Level: \(operation.level)")
                    Text("Capacity: \(operation.capacity)")
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)

                if operation.type == .production {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Mines")
                            .font(.headline)

                        ForEach(matchingMines.prefix(operation.capacity)) { mine in
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

                        ForEach(mockMachines.prefix(operation.capacity)) { machine in
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
        .navigationTitle(operation.name)
    }

    private var matchingMines: [Mine] {
        mockMines.filter { $0.buildingID == operation.id }
    }
}

#Preview {
    NavigationStack {
        OperationDetailView(
            operation: Operation(
                id: "op-gold-production",
                name: "Gold Production Operation",
                type: .production,
                level: 1,
                capacity: 2
            )
        )
    }
}
