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
            cost: 60_000
        ),
        PurchasableBuilding(
            id: "oil-refinery",
            name: "Oil Refinery",
            type: .refinery,
            cost: 62_000
        ),
        PurchasableBuilding(
            id: "coal-refinery",
            name: "Coal Refinery",
            type: .refinery,
            cost: 54_000
        ),
        PurchasableBuilding(
            id: "iron-refinery",
            name: "Iron Refinery",
            type: .refinery,
            cost: 58_000
        ),
        PurchasableBuilding(
            id: "gold-processing-plant",
            name: "Gold Processing Plant",
            type: .plant,
            cost: 98_000
        ),
        PurchasableBuilding(
            id: "fuel-processing-plant",
            name: "Fuel Processing Plant",
            type: .plant,
            cost: 92_000
        ),
        PurchasableBuilding(
            id: "fabrication-plant",
            name: "Fabrication Plant",
            type: .plant,
            cost: 108_000
        ),
        PurchasableBuilding(
            id: "material-depot",
            name: "Material Depot",
            type: .plant,
            cost: 74_000
        ),
        PurchasableBuilding(
            id: "jewelry-shop",
            name: "Jewelry Shop",
            type: .shop,
            cost: 118_000
        ),
        PurchasableBuilding(
            id: "tech-plant",
            name: "Tech Plant",
            type: .plant,
            cost: 132_000
        ),
        PurchasableBuilding(
            id: "steel-mill",
            name: "Steel Mill",
            type: .mill,
            cost: 70_000
        ),
        PurchasableBuilding(
            id: "silver-processing-plant",
            name: "Silver Processing Plant",
            type: .plant,
            cost: 102_000
        ),
        PurchasableBuilding(
            id: "diamond-processing-plant",
            name: "Diamond Processing Plant",
            type: .plant,
            cost: 125_000
        ),
        PurchasableBuilding(
            id: "diamond-refinery",
            name: "Diamond Refinery",
            type: .refinery,
            cost: 76_000
        ),
        PurchasableBuilding(
            id: "silver-refinery",
            name: "Silver Refinery",
            type: .refinery,
            cost: 61_000
        ),
        PurchasableBuilding(
            id: "construction-materials-plant",
            name: "Construction Materials Plant",
            type: .plant,
            cost: 88_000
        ),
        PurchasableBuilding(
            id: "research-and-development",
            name: "Research & Development",
            type: .researchAndDevelopment,
            cost: 145_000
        )
    ]

    static func cost(forBuildingName name: String) -> Double? {
        purchasableBuildings.first(where: { $0.name == name })?.cost
    }
}
