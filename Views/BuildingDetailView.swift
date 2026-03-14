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
    @StateObject private var viewModel: BuildingDetailViewModel

    init(userID: String, building: Building) {
        self.userID = userID
        self.building = building
        _viewModel = StateObject(wrappedValue: BuildingDetailViewModel(userID: userID, building: building))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Type: \(viewModel.currentBuilding.type.rawValue)")
                    Text("Level: \(viewModel.currentBuilding.level)")
                    Text("Capacity: \(viewModel.currentBuilding.capacity)")
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)

                if viewModel.currentBuilding.type == .mine || viewModel.currentBuilding.type == .rig || viewModel.currentBuilding.type == .quarry {
                    mineDetailsSection
                    productionSection
                    managementSection
                } else {
                    machinesSection
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle(viewModel.currentBuilding.name)
        .onAppear {
            viewModel.onDismiss = { dismiss() }
            viewModel.refreshBuilding()
        }
        .sheet(isPresented: $viewModel.showListingSheet) {
            listingSheetView
        }
    }

    private var mineDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mine Details")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Resource: \(viewModel.currentBuilding.resourceType?.rawValue ?? "Unknown")")
                Text("Abundance: \(viewModel.currentBuilding.abundance ?? 0)")
                Text("Stability: \(viewModel.currentBuilding.stability ?? 0)")
                Text("Starter Mine: \((viewModel.currentBuilding.isStarterMine ?? false) ? "Yes" : "No")")
                Text("Output Range: \(viewModel.formattedOutputRange())")

                if viewModel.currentBuilding.isListedOnMarket == true {
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
    }

    private var productionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Production")
                .font(.headline)

            TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(alignment: .leading, spacing: 8) {
                    Text("Producing: \((viewModel.currentBuilding.isProducing ?? false) ? "Yes" : "No")")

                    if viewModel.currentBuilding.isListedOnMarket == true {
                        Text("Production unavailable while listed on the market.")
                            .foregroundStyle(.secondary)
                    } else if viewModel.currentBuilding.isProducing == true {
                        if viewModel.isReadyToCollect(at: context.date) {
                            Text("Status: Ready to Collect")
                                .bold()

                            if let pendingOutputQuantity = viewModel.currentBuilding.pendingOutputQuantity,
                               pendingOutputQuantity > 0 {
                                Text("Output Ready: \(Int(pendingOutputQuantity))")
                            }
                        } else if let productionEndsAt = viewModel.currentBuilding.productionEndsAt {
                            Text("Time Remaining: \(viewModel.formattedTimeRemaining(until: productionEndsAt, now: context.date))")
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }

                if viewModel.isWorking {
                    ProgressView()
                } else if viewModel.currentBuilding.isListedOnMarket == true {
                    Text("This mine is currently listed on the marketplace.")
                        .foregroundStyle(.secondary)
                } else if viewModel.currentBuilding.isProducing == true {
                    if viewModel.isReadyToCollect(at: context.date) {
                        Button("Collect Output") {
                            viewModel.collectProduction()
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Text("Production is currently running.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Button("Start Production") {
                        viewModel.startProduction()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private var managementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Management")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("System Sell Value: $\(viewModel.scrapValue(), specifier: "%.2f")")
                    .font(.subheadline)

                if viewModel.currentBuilding.isListedOnMarket == true {
                    if let currentListing = viewModel.currentListing {
                        Text("Buy Now: $\(currentListing.buyNowPrice, specifier: "%.2f")")
                            .font(.subheadline)
                        Text("Current Bid: $\(currentListing.currentBid, specifier: "%.2f")")
                            .font(.subheadline)
                        if currentListing.currentBidderID == nil || currentListing.currentBidderID?.isEmpty == true {
                            Button("Cancel Listing") {
                                viewModel.cancelListing()
                            }
                            .buttonStyle(.bordered)
                            .disabled(viewModel.isWorking)
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
                        viewModel.openListingSheet()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isWorking || (viewModel.currentBuilding.isProducing ?? false))

                    Button("Sell to System") {
                        viewModel.sellToSystem()
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isWorking || (viewModel.currentBuilding.isProducing ?? false))
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }

    private var machinesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Machines")
                .font(.headline)

            ForEach(viewModel.mockMachines.prefix(viewModel.currentBuilding.capacity)) { machine in
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

    private var listingSheetView: some View {
        NavigationStack {
            Form {
                Section("Set Buy Now Price") {
                    TextField("Enter buy now price", text: $viewModel.buyNowPriceText)
                        .keyboardType(.decimalPad)

                    Text("Resource: \(viewModel.currentBuilding.resourceType?.rawValue ?? "Unknown")")
                    Text("Abundance: \(viewModel.currentBuilding.abundance ?? 0)")
                    Text("Stability: \(viewModel.currentBuilding.stability ?? 0)")
                    Text("Level: \(viewModel.currentBuilding.level)")

                    if let pricing = viewModel.suggestedPricing() {
                        Text("Suggested Starting Bid: $\(pricing.startingBid, specifier: "%.2f")")
                        Text("Suggested Buy Now Range: $\(pricing.suggestedBuyNowLow, specifier: "%.2f") - $\(pricing.suggestedBuyNowHigh, specifier: "%.2f")")
                            .foregroundStyle(.secondary)
                    }
                }

                if let errorMessage = viewModel.errorMessage {
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
                        viewModel.closeListingSheet()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("List") {
                        viewModel.listOwnedMine()
                    }
                    .disabled(viewModel.isWorking)
                }
            }
            .overlay {
                if viewModel.isWorking {
                    ProgressView("Listing...")
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(12)
                }
            }
        }
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
                slotIndex: 1,
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
