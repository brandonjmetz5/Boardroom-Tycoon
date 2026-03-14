//
//  OperationDetailViewModel.swift
//  Boardroom Tycoon
//
//  MVVM: Presentation logic and state for the Operation Detail screen.
//

import Foundation

@MainActor
final class OperationDetailViewModel: ObservableObject {
    let operation: Operation

    @Published private(set) var mines: [Mine] = []
    @Published private(set) var machines: [Machine] = []

    var matchingMines: [Mine] {
        mines.filter { $0.buildingID == operation.id }
    }

    init(operation: Operation) {
        self.operation = operation
        loadMockData()
    }

    private func loadMockData() {
        mines = [
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
        machines = [
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
    }
}
