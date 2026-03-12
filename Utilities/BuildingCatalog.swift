//
//  BuildingCatalog.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/12/26.
//

import Foundation

enum BuildingCatalog {
    static let purchasableBuildings: [PurchasableBuilding] = [
        PurchasableBuilding(
            id: "gold-refinery",
            name: "Gold Refinery",
            type: .refinery,
            cost: 2500
        ),
        PurchasableBuilding(
            id: "oil-refinery",
            name: "Oil Refinery",
            type: .refinery,
            cost: 3000
        ),
        PurchasableBuilding(
            id: "coal-refinery",
            name: "Coal Refinery",
            type: .refinery,
            cost: 2200
        ),
        PurchasableBuilding(
            id: "iron-refinery",
            name: "Iron Refinery",
            type: .refinery,
            cost: 2800
        ),
        PurchasableBuilding(
            id: "gold-processing-plant",
            name: "Gold Processing Plant",
            type: .plant,
            cost: 4000
        ),
        PurchasableBuilding(
            id: "fuel-processing-plant",
            name: "Fuel Processing Plant",
            type: .plant,
            cost: 3500
        ),
        PurchasableBuilding(
            id: "fabrication-plant",
            name: "Fabrication Plant",
            type: .plant,
            cost: 4500
        ),
        PurchasableBuilding(
            id: "material-depot",
            name: "Material Depot",
            type: .plant,
            cost: 2600
        ),
        PurchasableBuilding(
            id: "jewelry-shop",
            name: "Jewelry Shop",
            type: .shop,
            cost: 5000
        )
    ]
}
