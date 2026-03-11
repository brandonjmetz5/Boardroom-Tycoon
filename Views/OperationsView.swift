//
//  OperationsView.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/11/26.
//

import SwiftUI

struct OperationsView: View {
    let operations: [Operation] = [
        Operation(
            id: "op-gold-production",
            name: "Gold Production Operation",
            type: .production,
            level: 1,
            capacity: 2
        ),
        Operation(
            id: "op-gold-refinery",
            name: "Gold Refinery Operation",
            type: .refinery,
            level: 1,
            capacity: 2
        ),
        Operation(
            id: "op-jewelry",
            name: "Jewelry Operation",
            type: .retail,
            level: 1,
            capacity: 1
        )
    ]

    var body: some View {
        List(operations) { operation in
            NavigationLink(destination: OperationDetailView(operation: operation)) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(operation.name)
                        .font(.headline)

                    Text("Type: \(operation.type.rawValue)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Level: \(operation.level)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Capacity: \(operation.capacity)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.insetGrouped)
    }
}

#Preview {
    NavigationStack {
        OperationsView()
    }
}
