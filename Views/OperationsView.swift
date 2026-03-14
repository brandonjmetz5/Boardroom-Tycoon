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
    @State private var selectedEmptySlotIndex: Int?

    private let buildingService = BuildingService()
    private let playerProfileService = PlayerProfileService()
    private let prospectingService = ProspectingService()
    private let mineMarketService = MineMarketService()

    private let columns = [
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ZStack {
            Color(red: 0.03, green: 0.05, blue: 0.07)
                .ignoresSafeArea()

            Group {
                if isLoading {
                    ProgressView("Loading operations...")
                        .controlSize(.large)
                        .tint(.white)
                        .foregroundStyle(.white)
                } else if let loadingErrorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Failed to load operations")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text(loadingErrorMessage)
                            .foregroundStyle(.red)
                    }
                    .padding()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            headerSection
                            summarySection
                            slotsGridSection
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Operations")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .onAppear {
            mineMarketService.settleExpiredMineListings { _ in }
            loadData()
        }
        .sheet(isPresented: $showPurchaseSheet) {
            purchaseSheetView
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Manage your buildings, slots, and production.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.68))
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: columns, spacing: 12) {
                summaryRow
            }

            if let purchaseErrorMessage {
                Text(purchaseErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var summaryRow: some View {
        HStack(spacing: 10) {
            summaryPill(title: "Slots", value: "\(usedSlotsCount)/\(totalSlotsCount)")
            summaryPill(title: "Producing", value: "\(producingCount)")
            summaryPill(title: "Ready", value: "\(readyCount)")
            summaryPill(title: "Listed", value: "\(listedCount)")
        }
    }

    private func summaryPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.58))

            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.08, green: 0.11, blue: 0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
        )
    }

    private var slotsGridSection: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(buildingSlots) { slot in
                switch slot.content {
                case .building(let building):
                    buildingCard(for: building)

                case .prospecting(let job):
                    prospectingCard(for: job)

                case .empty:
                    emptySlotCard(slotIndex: slot.slotIndex)
                }
            }
        }
    }

    private func buildingCard(for building: Building) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            NavigationLink(destination: BuildingDetailView(userID: userID, building: building)) {
                ZStack(alignment: .leading) {
                    Image(buildingAssetName(for: building))
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, minHeight: 156, maxHeight: 156)
                        .clipped()
                        .opacity(0.34)

                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(Color(red: 0.07, green: 0.10, blue: 0.13).opacity(0.76))

                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Spacer()

                            statusChip(
                                title: buildingStatusText(for: building, now: context.date),
                                color: buildingStatusColor(for: building, now: context.date)
                            )
                        }

                        Spacer()

                        VStack(alignment: .leading, spacing: 8) {
                            Text(building.name)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)

                            Text(buildingFamilyLabel(for: building))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.68))
                                .lineLimit(1)

                            Text(buildingDetailText(for: building, now: context.date))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.56))
                        }
                    }
                    .padding(18)
                }
                .frame(maxWidth: .infinity, minHeight: 156, maxHeight: 156)
                .background(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(Color(red: 0.07, green: 0.10, blue: 0.13))
                )
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func prospectingCard(for job: ProspectingJob) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Button {
                handleProspectingTap(for: job, now: context.date)
            } label: {
                ZStack(alignment: .leading) {
                    Image(prospectingAssetName(for: job))
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, minHeight: 156, maxHeight: 156)
                        .clipped()
                        .opacity(0.34)

                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(Color(red: 0.08, green: 0.11, blue: 0.14).opacity(0.78))

                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Spacer()

                            statusChip(
                                title: job.endsAt <= context.date ? "Ready" : "Prospecting",
                                color: job.endsAt <= context.date
                                    ? Color(red: 0.24, green: 0.62, blue: 0.44)
                                    : Color(red: 0.30, green: 0.53, blue: 0.78)
                            )
                        }

                        Spacer()

                        VStack(alignment: .leading, spacing: 8) {
                            Text(prospectingLabel(for: job.resourceType))
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)

                            Text("Prospecting")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.68))

                            if job.endsAt <= context.date {
                                Text("Tap to reveal")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.56))
                            } else {
                                Text(formattedTimeRemaining(until: job.endsAt, now: context.date))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.56))
                            }
                        }
                    }
                    .padding(18)
                }
                .frame(maxWidth: .infinity, minHeight: 156, maxHeight: 156)
                .background(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(Color(red: 0.08, green: 0.11, blue: 0.14))
                )
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isPurchasing)
        }
    }

    private func emptySlotCard(slotIndex: Int) -> some View {
        Button {
            purchaseErrorMessage = nil
            selectedEmptySlotIndex = slotIndex
            showPurchaseSheet = true
        } label: {
            ZStack(alignment: .leading) {
                Image("icon_blueprint")
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, minHeight: 156, maxHeight: 156)
                    .clipped()
                    .opacity(0.34)

                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color(red: 0.07, green: 0.10, blue: 0.13).opacity(0.74))

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Spacer()

                        statusChip(
                            title: "Available",
                            color: Color(red: 0.37, green: 0.49, blue: 0.78)
                        )
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Open Slot")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)

                        Text("Build or Prospect")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.68))
                    }
                }
                .padding(18)
            }
            .frame(maxWidth: .infinity, minHeight: 156, maxHeight: 156)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color(red: 0.07, green: 0.10, blue: 0.13))
            )
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.white.opacity(0.04), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func statusChip(title: String, color: Color) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(color.opacity(0.92))
            )
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
                        selectedEmptySlotIndex = nil
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
                .disabled(isPurchasing || selectedEmptySlotIndex == nil)
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
        .disabled(isPurchasing || selectedEmptySlotIndex == nil)
    }

    private var activeProspectingJobs: [ProspectingJob] {
        prospectingJobs.filter { !$0.isComplete }
    }

    private var usedSlotsCount: Int {
        buildings.count + activeProspectingJobs.count
    }

    private var totalSlotsCount: Int {
        profile?.buildingSlotCount ?? usedSlotsCount
    }

    private var producingCount: Int {
        buildings.filter { $0.isProducing == true && !isReadyToCollect(building: $0, now: Date()) }.count
    }

    private var readyCount: Int {
        buildings.filter { isReadyToCollect(building: $0, now: Date()) }.count
    }

    private var listedCount: Int {
        buildings.filter { $0.isListedOnMarket == true }.count
    }

    private var buildingSlots: [BuildingSlot] {
        let totalSlots = profile?.buildingSlotCount ?? buildings.count
        var slots: [BuildingSlot] = []

        for slotIndex in 0..<totalSlots {
            if let building = buildings.first(where: { $0.slotIndex == slotIndex }) {
                slots.append(
                    BuildingSlot(
                        id: "slot-building-\(building.id)",
                        slotIndex: slotIndex,
                        content: .building(building)
                    )
                )
            } else if let job = activeProspectingJobs.first(where: { $0.slotIndex == slotIndex }) {
                slots.append(
                    BuildingSlot(
                        id: "slot-prospecting-\(job.id)",
                        slotIndex: slotIndex,
                        content: .prospecting(job)
                    )
                )
            } else {
                slots.append(
                    BuildingSlot(
                        id: "slot-empty-\(slotIndex)",
                        slotIndex: slotIndex,
                        content: .empty
                    )
                )
            }
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
        guard let selectedEmptySlotIndex else {
            purchaseErrorMessage = "Select an empty slot first."
            return
        }

        isPurchasing = true
        purchaseErrorMessage = nil

        buildingService.purchaseBuilding(
            for: userID,
            purchasableBuilding: purchasableBuilding,
            slotIndex: selectedEmptySlotIndex
        ) { result in
            DispatchQueue.main.async {
                self.isPurchasing = false

                switch result {
                case .success:
                    self.showPurchaseSheet = false
                    self.selectedEmptySlotIndex = nil
                    self.loadData()
                case .failure(let error):
                    self.purchaseErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private func startProspecting(_ resourceType: ResourceType) {
        guard let selectedEmptySlotIndex else {
            purchaseErrorMessage = "Select an empty slot first."
            return
        }

        isPurchasing = true
        purchaseErrorMessage = nil

        prospectingService.startProspecting(
            for: userID,
            resourceType: resourceType,
            slotIndex: selectedEmptySlotIndex
        ) { result in
            DispatchQueue.main.async {
                self.isPurchasing = false

                switch result {
                case .success:
                    self.showPurchaseSheet = false
                    self.selectedEmptySlotIndex = nil
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

    private func handleProspectingTap(for job: ProspectingJob, now: Date) {
        if job.endsAt <= now {
            revealProspectingJob(job)
        }
    }

    private func isReadyToCollect(building: Building, now: Date) -> Bool {
        guard
            building.isProducing == true,
            let productionEndsAt = building.productionEndsAt
        else {
            return false
        }

        return productionEndsAt <= now
    }

    private func buildingStatusText(for building: Building, now: Date) -> String {
        if building.isListedOnMarket == true {
            return "Listed"
        }

        if isReadyToCollect(building: building, now: now) {
            return "Ready"
        }

        if building.isProducing == true {
            return "Producing"
        }

        return "Idle"
    }

    private func buildingStatusColor(for building: Building, now: Date) -> Color {
        if building.isListedOnMarket == true {
            return Color(red: 0.42, green: 0.37, blue: 0.78)
        }

        if isReadyToCollect(building: building, now: now) {
            return Color(red: 0.24, green: 0.62, blue: 0.44)
        }

        if building.isProducing == true {
            return Color(red: 0.76, green: 0.55, blue: 0.22)
        }

        return Color(red: 0.34, green: 0.39, blue: 0.47)
    }

    private func buildingDetailText(for building: Building, now: Date) -> String {
        if building.isListedOnMarket == true {
            return "Level \(building.level)"
        }

        if isReadyToCollect(building: building, now: now) {
            return "Ready to collect"
        }

        if building.isProducing == true, let productionEndsAt = building.productionEndsAt {
            return formattedTimeRemaining(until: productionEndsAt, now: now)
        }

        return "Level \(building.level)"
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

    private func buildingFamilyLabel(for building: Building) -> String {
        if let resourceType = building.resourceType {
            switch resourceType {
            case .gold:
                return "Gold"
            case .silver:
                return "Silver"
            case .diamond:
                return "Diamond"
            case .oil:
                return "Oil"
            case .coal:
                return "Coal"
            case .iron:
                return "Iron"
            default:
                return building.type.rawValue
            }
        }

        return building.type.rawValue
    }

    private func buildingAssetName(for building: Building) -> String {
        let lowercasedName = building.name.lowercased()

        if lowercasedName.contains("stone quarry") {
            return "icon_stone_quarry"
        }

        if lowercasedName.contains("sand quarry") {
            return "icon_sand_quarry"
        }

        if lowercasedName.contains("gravel quarry") {
            return "icon_gravel_quarry"
        }

        if lowercasedName.contains("gold refinery") {
            return "icon_gold_refinery"
        }

        if lowercasedName.contains("silver refinery") {
            return "icon_silver_refinery"
        }

        if lowercasedName.contains("diamond refinery") {
            return "icon_diamond_refinery"
        }

        if lowercasedName.contains("coal refinery") {
            return "icon_coal_refinery"
        }

        if lowercasedName.contains("oil refinery") {
            return "icon_oil_refinery"
        }

        if lowercasedName.contains("fuel processing plant") {
            return "icon_fuel_processing_plant"
        }

        if lowercasedName.contains("construction materials") {
            return "icon_construction_materials_factory"
        }

        if lowercasedName.contains("materials depot") {
            return "icon_materials_depot"
        }

        if lowercasedName.contains("tech plant") {
            return "icon_tech_plant"
        }

        if lowercasedName.contains("fabrication plant") {
            return "icon_fabrication_plant"
        }

        if lowercasedName.contains("iron bar factory") {
            return "icon_iron_bar_factory"
        }

        if lowercasedName.contains("diamond processing plant") {
            return "icon_diamond_processing_plant"
        }

        if lowercasedName.contains("silver processing plant") {
            return "icon_silver_processing_plant"
        }

        if lowercasedName.contains("oil rig") {
            return "icon_oil_rig"
        }

        if lowercasedName.contains("coal mine") {
            return "icon_raw_coal_mine"
        }

        if lowercasedName.contains("silver mine") {
            return "icon_raw_silver_mine"
        }

        if lowercasedName.contains("diamond mine") {
            return "icon_raw_diamond_mine"
        }

        if lowercasedName.contains("gold mine") {
            return "icon_gold_refinery"
        }

        if lowercasedName.contains("iron mine") {
            return "icon_iron_bar_factory"
        }

        return "icon_blueprint"
    }

    private func prospectingAssetName(for job: ProspectingJob) -> String {
        switch job.resourceType {
        case .gold:
            return "icon_gold_refinery"
        case .silver:
            return "icon_raw_silver_mine"
        case .diamond:
            return "icon_raw_diamond_mine"
        case .oil:
            return "icon_oil_rig"
        case .coal:
            return "icon_raw_coal_mine"
        case .iron:
            return "icon_iron_bar_factory"
        default:
            return "icon_blueprint"
        }
    }
}

//private struct BuildingSlot: Identifiable {
//    let id: String
//    let slotIndex: Int
//    let content: Content
//
//    enum Content {
//        case building(Building)
//        case prospecting(ProspectingJob)
//        case empty
//    }
//}
//
#Preview {
    NavigationStack {
        OperationsView(userID: "demo-user-id-12345")
    }
}
