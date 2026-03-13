//
//  BuildingDetailView.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/12/26.
//

import SwiftUI

struct BuildingDetailView: View {
    let userID: String
    let building: Building

    @Environment(\.dismiss) private var dismiss

    @State private var currentBuilding: Building
    @State private var currentListing: MineMarketListing?
    @State private var isWorking = false
    @State private var errorMessage: String?

    @State private var showListingSheet = false
    @State private var buyNowPriceText = ""

    private let productionService = ProductionService()
    private let buildingService = BuildingService()
    private let mineMarketService = MineMarketService()

    init(userID: String, building: Building) {
        self.userID = userID
        self.building = building
        _currentBuilding = State(initialValue: building)
    }

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
                    Text("Type: \(currentBuilding.type.rawValue)")
                    Text("Level: \(currentBuilding.level)")
                    Text("Capacity: \(currentBuilding.capacity)")
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)

                if currentBuilding.type == .mine || currentBuilding.type == .rig || currentBuilding.type == .quarry {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Mine Details")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Resource: \(currentBuilding.resourceType?.rawValue ?? "Unknown")")
                            Text("Abundance: \(currentBuilding.abundance ?? 0)")
                            Text("Stability: \(currentBuilding.stability ?? 0)")
                            Text("Starter Mine: \((currentBuilding.isStarterMine ?? false) ? "Yes" : "No")")
                            Text("Output Range: \(formattedOutputRange())")

                            if currentBuilding.isListedOnMarket == true {
                                Text("Market Status: Listed on Market")
                                    .foregroundStyle(.orange)
                                    .bold()
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Production")
                            .font(.headline)

                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Producing: \((currentBuilding.isProducing ?? false) ? "Yes" : "No")")

                                if currentBuilding.isListedOnMarket == true {
                                    Text("Production unavailable while listed on the market.")
                                        .foregroundStyle(.secondary)
                                } else if currentBuilding.isProducing == true {
                                    if isReadyToCollect(at: context.date) {
                                        Text("Status: Ready to Collect")
                                            .bold()

                                        if let pendingOutputQuantity = currentBuilding.pendingOutputQuantity,
                                           pendingOutputQuantity > 0 {
                                            Text("Output Ready: \(Int(pendingOutputQuantity))")
                                        }
                                    } else if let productionEndsAt = currentBuilding.productionEndsAt {
                                        Text("Time Remaining: \(formattedTimeRemaining(until: productionEndsAt, now: context.date))")
                                    }
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)

                            if let errorMessage {
                                Text(errorMessage)
                                    .foregroundStyle(.red)
                            }

                            if isWorking {
                                ProgressView()
                            } else if currentBuilding.isListedOnMarket == true {
                                Text("This mine is currently listed on the marketplace.")
                                    .foregroundStyle(.secondary)
                            } else if currentBuilding.isProducing == true {
                                if isReadyToCollect(at: context.date) {
                                    Button("Collect Output") {
                                        collectProduction()
                                    }
                                    .buttonStyle(.borderedProminent)
                                } else {
                                    Text("Production is currently running.")
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Button("Start Production") {
                                    startProduction()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Management")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("System Sell Value: $\(scrapValue(), specifier: "%.2f")")
                                .font(.subheadline)

                            if currentBuilding.isListedOnMarket == true {
                                if let currentListing {
                                    Text("Buy Now: $\(currentListing.buyNowPrice, specifier: "%.2f")")
                                        .font(.subheadline)

                                    Text("Current Bid: $\(currentListing.currentBid, specifier: "%.2f")")
                                        .font(.subheadline)

                                    if currentListing.currentBidderID == nil || currentListing.currentBidderID?.isEmpty == true {
                                        Button("Cancel Listing") {
                                            cancelListing()
                                        }
                                        .buttonStyle(.bordered)
                                        .disabled(isWorking)
                                    } else {
                                        Text("This listing has bids and cannot be cancelled.")
                                            .foregroundStyle(.secondary)
                                    }
                                } else {
                                    Text("Loading listing details...")
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Button("List on Marketplace") {
                                    errorMessage = nil
                                    buyNowPriceText = ""
                                    showListingSheet = true
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(isWorking || (currentBuilding.isProducing ?? false))

                                Button("Sell to System") {
                                    sellToSystem()
                                }
                                .buttonStyle(.bordered)
                                .disabled(isWorking || (currentBuilding.isProducing ?? false))
                            }
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

                        ForEach(mockMachines.prefix(currentBuilding.capacity)) { machine in
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
        .navigationTitle(currentBuilding.name)
        .onAppear {
            refreshBuilding()
        }
        .sheet(isPresented: $showListingSheet) {
            NavigationStack {
                Form {
                    Section("Set Buy Now Price") {
                        TextField("Enter buy now price", text: $buyNowPriceText)
                            .keyboardType(.decimalPad)

                        Text("Resource: \(currentBuilding.resourceType?.rawValue ?? "Unknown")")
                        Text("Abundance: \(currentBuilding.abundance ?? 0)")
                        Text("Stability: \(currentBuilding.stability ?? 0)")
                        Text("Level: \(currentBuilding.level)")

                        if let pricing = suggestedPricing() {
                            Text("Suggested Starting Bid: $\(pricing.startingBid, specifier: "%.2f")")
                            Text("Suggested Buy Now Range: $\(pricing.suggestedBuyNowLow, specifier: "%.2f") - $\(pricing.suggestedBuyNowHigh, specifier: "%.2f")")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let errorMessage {
                        Section {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .navigationTitle("List Mine")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") {
                            showListingSheet = false
                            buyNowPriceText = ""
                            errorMessage = nil
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button("List") {
                            listOwnedMine()
                        }
                        .disabled(isWorking)
                    }
                }
                .overlay {
                    if isWorking {
                        ProgressView("Listing...")
                            .padding()
                            .background(.regularMaterial)
                            .cornerRadius(12)
                    }
                }
            }
        }
    }

    private func isReadyToCollect(at date: Date) -> Bool {
        guard let productionEndsAt = currentBuilding.productionEndsAt else { return false }
        return currentBuilding.isProducing == true && productionEndsAt <= date
    }

    private func refreshBuilding() {
        buildingService.fetchBuildings(for: userID) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let buildings):
                    if let updated = buildings.first(where: { $0.id == currentBuilding.id }) {
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

        mineMarketService.fetchMineListing(by: listingID) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let listing):
                    self.currentListing = listing
                case .failure:
                    self.currentListing = nil
                }
            }
        }
    }

    private func startProduction() {
        isWorking = true
        errorMessage = nil

        productionService.startProduction(for: userID, buildingID: currentBuilding.id) { result in
            DispatchQueue.main.async {
                self.isWorking = false

                switch result {
                case .success:
                    refreshBuilding()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func collectProduction() {
        isWorking = true
        errorMessage = nil

        productionService.collectProduction(for: userID, buildingID: currentBuilding.id) { result in
            DispatchQueue.main.async {
                self.isWorking = false

                switch result {
                case .success:
                    refreshBuilding()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func sellToSystem() {
        isWorking = true
        errorMessage = nil

        buildingService.sellBuildingToSystem(
            for: userID,
            building: currentBuilding,
            sellValue: scrapValue()
        ) { result in
            DispatchQueue.main.async {
                self.isWorking = false

                switch result {
                case .success:
                    dismiss()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func listOwnedMine() {
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
        ) { result in
            DispatchQueue.main.async {
                self.isWorking = false

                switch result {
                case .success:
                    self.showListingSheet = false
                    self.buyNowPriceText = ""
                    dismiss()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func cancelListing() {
        guard let currentListing else { return }

        isWorking = true
        errorMessage = nil

        mineMarketService.cancelMineListing(for: userID, listing: currentListing) { result in
            DispatchQueue.main.async {
                self.isWorking = false

                switch result {
                case .success:
                    dismiss()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func suggestedPricing() -> (startingBid: Double, suggestedBuyNowLow: Double, suggestedBuyNowHigh: Double)? {
        guard
            let resourceType = currentBuilding.resourceType,
            let abundance = currentBuilding.abundance,
            let stability = currentBuilding.stability
        else {
            return nil
        }

        let baseValue: Double

        switch resourceType {
        case .gold:
            baseValue = 800
        case .silver:
            baseValue = 700
        case .diamond:
            baseValue = 1200
        case .oil:
            baseValue = 900
        case .coal:
            baseValue = 650
        case .iron:
            baseValue = 750
        default:
            baseValue = 700
        }

        let statBonus = Double((abundance - 50) + (stability - 50)) * 12.0
        let levelBonus = Double(currentBuilding.level - 1) * 150.0

        let startingBid = max(100, baseValue + statBonus + levelBonus)
        let suggestedBuyNowLow = startingBid * 1.35
        let suggestedBuyNowHigh = startingBid * 1.75

        return (startingBid, suggestedBuyNowLow, suggestedBuyNowHigh)
    }

    private func formattedTimeRemaining(until endDate: Date, now: Date) -> String {
        let remainingSeconds = max(0, Int(ceil(endDate.timeIntervalSince(now))))
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func formattedOutputRange() -> String {
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

    private func scrapValue() -> Double {
        guard let resourceType = currentBuilding.resourceType else {
            return 250
        }

        let baseValue: Double

        switch resourceType {
        case .gold:
            baseValue = 500
        case .silver:
            baseValue = 425
        case .diamond:
            baseValue = 700
        case .oil:
            baseValue = 550
        case .coal:
            baseValue = 400
        case .iron:
            baseValue = 450
        default:
            baseValue = 400
        }

        let abundanceBonus = Double((currentBuilding.abundance ?? 50) - 50) * 4.0
        let stabilityBonus = Double((currentBuilding.stability ?? 50) - 50) * 4.0
        let levelBonus = Double(currentBuilding.level - 1) * 100.0

        return max(100, baseValue + abundanceBonus + stabilityBonus + levelBonus)
    }
}

#Preview {
    NavigationStack {
        BuildingDetailView(
            userID: "demo-user-id-12345",
            building: Building(
                id: "building-starter-gold-mine",
                name: "Starter Gold Mine",
                type: .mine,
                level: 1,
                capacity: 1,
                resourceType: .gold,
                abundance: 50,
                stability: 55,
                isStarterMine: true,
                isProducing: false,
                productionStartedAt: nil,
                productionEndsAt: nil,
                pendingOutputQuantity: nil,
                isListedOnMarket: false,
                marketListingID: nil
            )
        )
    }
}
