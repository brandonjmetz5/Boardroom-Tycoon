//
//  OperationDetailView.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/11/26.
//

import SwiftUI

struct OperationDetailView: View {
    let operation: Operation

    @StateObject private var viewModel: OperationDetailViewModel

    init(operation: Operation) {
        self.operation = operation
        _viewModel = StateObject(wrappedValue: OperationDetailViewModel(operation: operation))
    }

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

                        ForEach(viewModel.matchingMines.prefix(operation.capacity)) { mine in
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

                        ForEach(viewModel.machines.prefix(operation.capacity)) { machine in
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
