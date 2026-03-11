//
//  InventoryView.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/11/26.
//

import SwiftUI

struct InventoryView: View {
    let inventoryItems: [InventoryItem] = [
        InventoryItem(
            id: "inv-gold-bar",
            item: Item(id: "gold-bar", name: "Gold Bar", category: .refinedMaterial, isFractional: true),
            quantity: 0.75
        ),
        InventoryItem(
            id: "inv-fuel-cell",
            item: Item(id: "fuel-cell", name: "Fuel Cell", category: .fuel, isFractional: false),
            quantity: 12
        ),
        InventoryItem(
            id: "inv-cut-diamond",
            item: Item(id: "cut-diamond", name: "Cut Diamond", category: .refinedMaterial, isFractional: false),
            quantity: 3
        ),
        InventoryItem(
            id: "inv-steel",
            item: Item(id: "steel", name: "Steel", category: .buildingMaterial, isFractional: false),
            quantity: 5
        )
    ]

    var body: some View {
        List(inventoryItems) { inventoryItem in
            VStack(alignment: .leading, spacing: 4) {
                Text(inventoryItem.item.name)
                    .font(.headline)

                Text("Quantity: \(formattedQuantity(for: inventoryItem))")
                    .font(.subheadline)

                Text("Category: \(inventoryItem.item.category.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .listStyle(.insetGrouped)
    }

    private func formattedQuantity(for inventoryItem: InventoryItem) -> String {
        if inventoryItem.item.isFractional {
            return String(format: "%.2f", inventoryItem.quantity)
        } else {
            return String(Int(inventoryItem.quantity))
        }
    }
}

#Preview {
    NavigationStack {
        InventoryView()
    }
}
