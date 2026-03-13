//
//  OperationsView.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/11/26.
//

import SwiftUI

struct OperationsView: View {
    let userID: String

    @State private var buildings: [Building] = []
    @State private var profile: PlayerProfile?
    @State private var prospectingJobs: [ProspectingJob] = []
    @State private var isLoading = true
    @State private var loadingErrorMessage: String?
    @State private var purchaseErrorMessage: String?
    @State private var showPurchaseSheet = false
    @State private var isPurchasing = false

    @State private var jobToList: ProspectingJob?
    @State private var buyNowPriceText = ""

    private let buildingService = BuildingService()
    private let playerProfileService = PlayerProfileService()
    private let prospectingService = ProspectingService()
    private let mineMarketService = MineMarketService()

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading buildings...")
                    .controlSize(.large)
            } else if let loadingErrorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Failed to load buildings")
                        .font(.headline)

                    Text(loadingErrorMessage)
                        .foregroundStyle(.red)
                }
                .padding()
            } else {
                List(buildingSlots) { slot in
                    switch slot.content {
                    case .building(let building):
                        buildingRow(for: building)

                    case .prospecting(let job):
                        prospectingRow(for: job)

                    case .empty:
                        emptySlotRow
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Buildings")
        .onAppear {
            mineMarketService.settleExpiredMineListings { _ in }
            loadData()
        }
        .sheet(isPresented: $showPurchaseSheet) {
            purchaseSheetView
        }
        .sheet(item: $jobToList) { job in
            NavigationStack {
                Form {
                    Section("Set Buy Now Price") {
                        TextField("Enter buy now price", text: $buyNowPriceText)
                            .keyboardType(.decimalPad)

                        if let abundance = job.revealedAbundance,
                           let stability = job.revealedStability {
                            Text("Resource: \(prospectingLabel(for: job.resourceType))")
                            Text("Abundance: \(abundance)")
                            Text("Stability: \(stability)")
                        }
                    }

                    if let purchaseErrorMessage {
                        Section {
                            Text(purchaseErrorMessage)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .navigationTitle("List Mine")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") {
                            jobToList = nil
                            buyNowPriceText = ""
                            purchaseErrorMessage = nil
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button("List") {
                            submitMineListing(job)
                        }
                        .disabled(isPurchasing)
                    }
                }
                .overlay {
                    if isPurchasing {
                        ProgressView("Listing...")
                            .padding()
                            .background(.regularMaterial)
                            .cornerRadius(12)
                    }
                }
            }
        }
    }

    private func buildingRow(for building: Building) -> some View {
        NavigationLink(destination: BuildingDetailView(userID: userID, building: building)) {
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

                if building.isListedOnMarket == true {
                    Text("Listed on Market")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func prospectingRow(for job: ProspectingJob) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 8) {
                Text("Prospecting \(prospectingLabel(for: job.resourceType))")
                    .font(.headline)

                if job.isRevealed {
                    Text("Prospecting Result Revealed")
                        .font(.subheadline)
                        .bold()

                    if let abundance = job.revealedAbundance,
                       let stability = job.revealedStability {
                        Text("Abundance: \(abundance)")
                            .font(.subheadline)

                        Text("Stability: \(stability)")
                            .font(.subheadline)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Button("Keep Mine") {
                            keepProspectedMine(job)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isPurchasing)

                        Button("Sell Prospect Result") {
                            sellProspectedMine(job)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isPurchasing)

                        Button("List on Marketplace") {
                            purchaseErrorMessage = nil
                            buyNowPriceText = ""
                            jobToList = job
                        }
                        .buttonStyle(.bordered)
                        .disabled(isPurchasing)
                    }
                } else if job.endsAt <= context.date {
                    Text("Ready to Reveal")
                        .font(.subheadline)
                        .bold()

                    Button("Reveal Prospecting Result") {
                        revealProspectingJob(job)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isPurchasing)
                } else {
                    Text("Time Remaining: \(formattedTimeRemaining(until: job.endsAt, now: context.date))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("This slot is occupied by an active prospecting job.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let purchaseErrorMessage, jobToList == nil {
                    Text(purchaseErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var emptySlotRow: some View {
        Button {
            purchaseErrorMessage = nil
            showPurchaseSheet = true
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Empty Slot")
                    .font(.headline)

                Text("Tap to use this slot")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private var purchaseSheetView: some View {
        NavigationStack {
            List {
                purchaseErrorSection
                buyBuildingSection
                prospectResourceSection
            }
            .navigationTitle("Use Empty Slot")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        showPurchaseSheet = false
                    }
                }
            }
            .overlay {
                if isPurchasing {
                    ProgressView("Processing...")
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(12)
                }
            }
        }
    }

    @ViewBuilder
    private var purchaseErrorSection: some View {
        if let purchaseErrorMessage {
            Section {
                Text(purchaseErrorMessage)
                    .foregroundStyle(.red)
            }
        }
    }

    private var buyBuildingSection: some View {
        Section("Buy Building") {
            ForEach(BuildingCatalog.purchasableBuildings) { purchasableBuilding in
                Button {
                    purchaseBuilding(purchasableBuilding)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(purchasableBuilding.name)
                            .font(.headline)

                        Text("Type: \(purchasableBuilding.type.rawValue)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("Cost: $\(purchasableBuilding.cost, specifier: "%.2f")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .disabled(isPurchasing)
            }
        }
    }

    private var prospectResourceSection: some View {
        Section("Prospect Resource Site") {
            prospectButton(title: "Prospect Gold Mine", resourceType: .gold)
            prospectButton(title: "Prospect Silver Mine", resourceType: .silver)
            prospectButton(title: "Prospect Diamond Mine", resourceType: .diamond)
            prospectButton(title: "Prospect Oil Rig", resourceType: .oil)
            prospectButton(title: "Prospect Coal Mine", resourceType: .coal)
            prospectButton(title: "Prospect Iron Mine", resourceType: .iron)
        }
    }

    private func prospectButton(title: String, resourceType: ResourceType) -> some View {
        Button {
            startProspecting(resourceType)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text("Uses 1 building slot while active")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .disabled(isPurchasing)
    }

    private var activeProspectingJobs: [ProspectingJob] {
        prospectingJobs.filter { !$0.isComplete }
    }

    private var buildingSlots: [BuildingSlot] {
        let totalSlots = profile?.buildingSlotCount ?? buildings.count
        var slots: [BuildingSlot] = []

        for building in buildings {
            slots.append(
                BuildingSlot(
                    id: "slot-building-\(building.id)",
                    content: .building(building)
                )
            )
        }

        for job in activeProspectingJobs {
            slots.append(
                BuildingSlot(
                    id: "slot-prospecting-\(job.id)",
                    content: .prospecting(job)
                )
            )
        }

        let usedSlots = buildings.count + activeProspectingJobs.count
        let emptySlotCount = max(0, totalSlots - usedSlots)

        for index in 0..<emptySlotCount {
            slots.append(
                BuildingSlot(
                    id: "slot-empty-\(index)",
                    content: .empty
                )
            )
        }

        return slots
    }

    private func loadData() {
        isLoading = true
        loadingErrorMessage = nil

        let group = DispatchGroup()

        group.enter()
        playerProfileService.fetchPlayerProfile(for: userID) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let loadedProfile):
                    self.profile = loadedProfile
                case .failure(let error):
                    self.loadingErrorMessage = error.localizedDescription
                }
                group.leave()
            }
        }

        group.enter()
        buildingService.fetchBuildings(for: userID) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let loadedBuildings):
                    self.buildings = loadedBuildings
                case .failure(let error):
                    self.loadingErrorMessage = error.localizedDescription
                }
                group.leave()
            }
        }

        group.enter()
        prospectingService.fetchProspectingJobs(for: userID) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let loadedJobs):
                    self.prospectingJobs = loadedJobs
                case .failure(let error):
                    self.loadingErrorMessage = error.localizedDescription
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            self.isLoading = false
        }
    }

    private func purchaseBuilding(_ purchasableBuilding: PurchasableBuilding) {
        isPurchasing = true
        purchaseErrorMessage = nil

        buildingService.purchaseBuilding(for: userID, purchasableBuilding: purchasableBuilding) { result in
            DispatchQueue.main.async {
                self.isPurchasing = false

                switch result {
                case .success:
                    self.showPurchaseSheet = false
                    self.loadData()
                case .failure(let error):
                    self.purchaseErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private func startProspecting(_ resourceType: ResourceType) {
        isPurchasing = true
        purchaseErrorMessage = nil

        prospectingService.startProspecting(for: userID, resourceType: resourceType) { result in
            DispatchQueue.main.async {
                self.isPurchasing = false

                switch result {
                case .success:
                    self.showPurchaseSheet = false
                    self.loadData()
                case .failure(let error):
                    self.purchaseErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private func revealProspectingJob(_ job: ProspectingJob) {
        isPurchasing = true
        purchaseErrorMessage = nil

        prospectingService.revealProspectingJob(for: userID, jobID: job.id) { result in
            DispatchQueue.main.async {
                self.isPurchasing = false

                switch result {
                case .success:
                    self.loadData()
                case .failure(let error):
                    self.purchaseErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private func keepProspectedMine(_ job: ProspectingJob) {
        isPurchasing = true
        purchaseErrorMessage = nil

        prospectingService.keepProspectedMine(for: userID, job: job) { result in
            DispatchQueue.main.async {
                self.isPurchasing = false

                switch result {
                case .success:
                    self.loadData()
                case .failure(let error):
                    self.purchaseErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private func sellProspectedMine(_ job: ProspectingJob) {
        isPurchasing = true
        purchaseErrorMessage = nil

        prospectingService.sellProspectedMine(for: userID, job: job) { result in
            DispatchQueue.main.async {
                self.isPurchasing = false

                switch result {
                case .success:
                    self.loadData()
                case .failure(let error):
                    self.purchaseErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private func submitMineListing(_ job: ProspectingJob) {
        guard let buyNowPrice = Double(buyNowPriceText), buyNowPrice > 0 else {
            purchaseErrorMessage = "Enter a valid buy now price."
            return
        }

        isPurchasing = true
        purchaseErrorMessage = nil

        prospectingService.listProspectedMine(for: userID, job: job, buyNowPrice: buyNowPrice) { result in
            DispatchQueue.main.async {
                self.isPurchasing = false

                switch result {
                case .success:
                    self.jobToList = nil
                    self.buyNowPriceText = ""
                    self.loadData()
                case .failure(let error):
                    self.purchaseErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private func formattedTimeRemaining(until endDate: Date, now: Date) -> String {
        let remainingSeconds = max(0, Int(ceil(endDate.timeIntervalSince(now))))
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func prospectingLabel(for resourceType: ResourceType) -> String {
        switch resourceType {
        case .gold:
            return "Gold Mine"
        case .silver:
            return "Silver Mine"
        case .diamond:
            return "Diamond Mine"
        case .oil:
            return "Oil Rig"
        case .coal:
            return "Coal Mine"
        case .iron:
            return "Iron Mine"
        default:
            return resourceType.rawValue
        }
    }
}

#Preview {
    NavigationStack {
        OperationsView(userID: "demo-user-id-12345")
    }
}
