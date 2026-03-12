//
//  OperationsView.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/11/26.
//

import SwiftUI

struct OperationsView: View {
    let userID: String

    let buildings: [Building] = [
        Building(
            id: "building-gold-mine",
            name: "Gold Mine",
            type: .mine,
            level: 1,
            capacity: 2
        ),
        Building(
            id: "building-gold-refinery",
            name: "Gold Refinery",
            type: .refinery,
            level: 1,
            capacity: 2
        ),
        Building(
            id: "building-jewelry-shop",
            name: "Jewelry Shop",
            type: .shop,
            level: 1,
            capacity: 1
        )
    ]

    var body: some View {
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

#Preview {
    NavigationStack {
        OperationsView(userID: "demo-user-id-12345")
    }
}
