//
//  BuildingDetailViewModel.swift
//  Boardroom Tycoon
//
//  MVVM: Presentation logic and state for the Building Detail screen.
//

import Foundation
import SwiftUI

@MainActor
final class BuildingDetailViewModel: ObservableObject {
    let userID: String

    @Published private(set) var currentBuilding: Building
    @Published private(set) var currentListing: MineMarketListing?
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?

    @Published var showListingSheet = false
    @Published var buyNowPriceText = ""

    private let productionService = ProductionService()
    private let buildingService = BuildingService()
    private let mineMarketService = MineMarketService()

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

    var onDismiss: (() -> Void)?

    init(userID: String, building: Building) {
        self.userID = userID
        self.currentBuilding = building
    }

    // MARK: - Actions

    func refreshBuilding() {
        buildingService.fetchBuildings(for: userID) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let buildings):
                    if let updated = buildings.first(where: { $0.id == self.currentBuilding.id }) {
                        self.currentBuilding = updated
                        self.refreshListingIfNeeded()
                    }
                case .failure:
                    break
                }
            }
        }
    }

    private func refreshListingIfNeeded() {
        guard currentBuilding.isListedOnMarket == true,
              let listingID = currentBuilding.marketListingID,
              !listingID.isEmpty
        else {
            currentListing = nil
            return
        }

        mineMarketService.fetchMineListing(by: listingID) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let listing):
                    self.currentListing = listing
                case .failure:
                    self.currentListing = nil
                }
            }
        }
    }

    func startProduction() {
        isWorking = true
        errorMessage = nil

        productionService.startProduction(for: userID, buildingID: currentBuilding.id) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isWorking = false
                switch result {
                case .success:
                    self.refreshBuilding()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func collectProduction() {
        isWorking = true
        errorMessage = nil

        productionService.collectProduction(for: userID, buildingID: currentBuilding.id) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isWorking = false
                switch result {
                case .success:
                    self.refreshBuilding()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func sellToSystem() {
        isWorking = true
        errorMessage = nil

        buildingService.sellBuildingToSystem(
            for: userID,
            building: currentBuilding,
            sellValue: scrapValue()
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isWorking = false
                switch result {
                case .success:
                    self.onDismiss?()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func listOwnedMine() {
        guard let buyNowPrice = Double(buyNowPriceText), buyNowPrice > 0 else {
            errorMessage = "Enter a valid buy now price."
            return
        }

        isWorking = true
        errorMessage = nil

        mineMarketService.listOwnedMineOnMarket(
            for: userID,
            building: currentBuilding,
            buyNowPrice: buyNowPrice
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isWorking = false
                switch result {
                case .success:
                    self.showListingSheet = false
                    self.buyNowPriceText = ""
                    self.onDismiss?()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func cancelListing() {
        guard let currentListing else { return }

        isWorking = true
        errorMessage = nil

        mineMarketService.cancelMineListing(for: userID, listing: currentListing) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isWorking = false
                switch result {
                case .success:
                    self.onDismiss?()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func openListingSheet() {
        errorMessage = nil
        buyNowPriceText = ""
        showListingSheet = true
    }

    func closeListingSheet() {
        showListingSheet = false
        buyNowPriceText = ""
        errorMessage = nil
    }

    // MARK: - Display helpers

    func isReadyToCollect(at date: Date) -> Bool {
        guard let productionEndsAt = currentBuilding.productionEndsAt else { return false }
        return currentBuilding.isProducing == true && productionEndsAt <= date
    }

    func suggestedPricing() -> (startingBid: Double, suggestedBuyNowLow: Double, suggestedBuyNowHigh: Double)? {
        guard
            let resourceType = currentBuilding.resourceType,
            let abundance = currentBuilding.abundance,
            let stability = currentBuilding.stability
        else {
            return nil
        }

        let baseValue: Double
        switch resourceType {
        case .gold: baseValue = 800
        case .silver: baseValue = 700
        case .diamond: baseValue = 1200
        case .oil: baseValue = 900
        case .coal: baseValue = 650
        case .iron: baseValue = 750
        default: baseValue = 700
        }

        let statBonus = Double((abundance - 50) + (stability - 50)) * 12.0
        let levelBonus = Double(currentBuilding.level - 1) * 150.0
        let startingBid = max(100, baseValue + statBonus + levelBonus)
        let suggestedBuyNowLow = startingBid * 1.35
        let suggestedBuyNowHigh = startingBid * 1.75
        return (startingBid, suggestedBuyNowLow, suggestedBuyNowHigh)
    }

    func formattedTimeRemaining(until endDate: Date, now: Date) -> String {
        let remainingSeconds = max(0, Int(ceil(endDate.timeIntervalSince(now))))
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func formattedOutputRange() -> String {
        guard
            let abundance = currentBuilding.abundance,
            let stability = currentBuilding.stability
        else {
            return "Unknown"
        }

        let maxOutput = max(1, abundance - 40)
        let normalizedStability = Double(stability - 50) / 50.0
        let stabilityMultiplier = 0.5 + (normalizedStability * 0.4)
        let minOutput = max(1, Int((Double(maxOutput) * stabilityMultiplier).rounded(.down)))
        return "\(minOutput)-\(maxOutput)"
    }

    func scrapValue() -> Double {
        guard let resourceType = currentBuilding.resourceType else {
            return 250
        }

        let baseValue: Double
        switch resourceType {
        case .gold: baseValue = 500
        case .silver: baseValue = 425
        case .diamond: baseValue = 700
        case .oil: baseValue = 550
        case .coal: baseValue = 400
        case .iron: baseValue = 450
        default: baseValue = 400
        }

        let abundanceBonus = Double((currentBuilding.abundance ?? 50) - 50) * 4.0
        let stabilityBonus = Double((currentBuilding.stability ?? 50) - 50) * 4.0
        let levelBonus = Double(currentBuilding.level - 1) * 100.0
        return max(100, baseValue + abundanceBonus + stabilityBonus + levelBonus)
    }
}
