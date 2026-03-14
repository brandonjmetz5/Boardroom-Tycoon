//
//  OperationsView.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/11/26.
//

import SwiftUI

struct OperationsView: View {
    let userID: String

    @StateObject private var viewModel: OperationsViewModel

    init(userID: String) {
        self.userID = userID
        _viewModel = StateObject(wrappedValue: OperationsViewModel(userID: userID))
    }

    private let columns = [
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            Group {
                if viewModel.isLoading {
                    ProgressView("Loading operations...")
                        .controlSize(.large)
                        .tint(AppTheme.accent)
                        .foregroundStyle(AppTheme.textSecondary)
                } else if let loadingErrorMessage = viewModel.loadingErrorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Failed to load operations")
                            .font(AppTheme.titleSmall())
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(loadingErrorMessage)
                            .font(AppTheme.caption())
                            .foregroundStyle(AppTheme.textError)
                    }
                    .padding(AppTheme.cardPadding)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                            headerSection
                            summarySection
                            slotsGridSection
                        }
                        .padding(.horizontal, AppTheme.horizontalPadding)
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
                    .font(AppTheme.titleMedium())
                    .foregroundStyle(AppTheme.textPrimary)
            }
        }
        .onAppear {
            viewModel.loadData()
        }
        .sheet(isPresented: Binding(
            get: { viewModel.showPurchaseSheet },
            set: { viewModel.showPurchaseSheet = $0 }
        )) {
            purchaseSheetView
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Manage your buildings, slots, and production.")
                .font(AppTheme.caption())
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: columns, spacing: 12) {
                summaryRow
            }

            if let purchaseErrorMessage = viewModel.purchaseErrorMessage {
                Text(purchaseErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var summaryRow: some View {
        HStack(spacing: 10) {
            summaryPill(title: "Slots", value: "\(viewModel.usedSlotsCount)/\(viewModel.totalSlotsCount)")
            summaryPill(title: "Producing", value: "\(viewModel.producingCount)")
            summaryPill(title: "Ready", value: "\(viewModel.readyCount)")
            summaryPill(title: "Listed", value: "\(viewModel.listedCount)")
        }
    }

    private func summaryPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppTheme.captionMedium())
                .foregroundStyle(AppTheme.textTertiary)
            Text(value)
                .font(AppTheme.monoNumber())
                .foregroundStyle(AppTheme.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.cardPadding)
        .appPill()
    }

    private var slotsGridSection: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(viewModel.buildingSlots) { slot in
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
                    Image(viewModel.buildingAssetName(for: building))
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, minHeight: 156, maxHeight: 156)
                        .clipped()
                        .opacity(0.34)

                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(AppTheme.surface.opacity(0.9))

                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Spacer()

                            statusChip(
                                title: viewModel.buildingStatusText(for: building, now: context.date),
                                color: statusColor(for: viewModel.buildingStatus(for: building, now: context.date))
                            )
                        }

                        Spacer()

                        VStack(alignment: .leading, spacing: 8) {
                            Text(building.name)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)

                            Text(viewModel.buildingFamilyLabel(for: building))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.68))
                                .lineLimit(1)

                            Text(viewModel.buildingDetailText(for: building, now: context.date))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.56))
                            if viewModel.buildingStatus(for: building, now: context.date) == .idle,
                               let hint = viewModel.productionInputHint(for: building) {
                                Text("Input: \(hint)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.5))
                            }
                        }
                    }
                    .padding(18)
                }
                .frame(maxWidth: .infinity, minHeight: 156, maxHeight: 156)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                        .fill(AppTheme.surface)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func prospectingCard(for job: ProspectingJob) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Button {
                if job.endsAt <= context.date {
                    viewModel.revealProspectingJob(job)
                }
            } label: {
                ZStack(alignment: .leading) {
                    Image(viewModel.prospectingAssetName(for: job))
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, minHeight: 156, maxHeight: 156)
                        .clipped()
                        .opacity(0.34)

                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                        .fill(AppTheme.surfaceAlt.opacity(0.9))

                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Spacer()

                            statusChip(
                                title: job.endsAt <= context.date ? "Ready" : "Prospecting",
                                color: job.endsAt <= context.date
                                    ? AppTheme.chipReady
                                    : AppTheme.chipProspecting
                            )
                        }

                        Spacer()

                        VStack(alignment: .leading, spacing: 8) {
                            Text(viewModel.prospectingLabel(for: job.resourceType))
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
                                Text(viewModel.formattedTimeRemaining(until: job.endsAt, now: context.date))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.56))
                            }
                        }
                    }
                    .padding(18)
                }
                .frame(maxWidth: .infinity, minHeight: 156, maxHeight: 156)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                        .fill(AppTheme.surfaceAlt)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isPurchasing)
        }
    }

    private func emptySlotCard(slotIndex: Int) -> some View {
        Button {
            viewModel.openPurchaseSheet(slotIndex: slotIndex)
        } label: {
            ZStack(alignment: .leading) {
                Image("icon_blueprint")
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, minHeight: 156, maxHeight: 156)
                    .clipped()
                    .opacity(0.34)

                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                    .fill(AppTheme.surface.opacity(0.9))

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Spacer()

                        statusChip(
                            title: "Available",
                            color: AppTheme.chipAvailable
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
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                    .fill(AppTheme.surface)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
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

    private func statusColor(for status: BuildingStatusDisplay) -> Color {
        switch status {
        case .listed: return AppTheme.chipListed
        case .ready: return AppTheme.chipReady
        case .producing: return AppTheme.chipProducing
        case .idle: return AppTheme.chipIdle
        }
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
                        viewModel.closePurchaseSheet()
                    }
                }
            }
            .overlay {
                if viewModel.isPurchasing {
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
        if let purchaseErrorMessage = viewModel.purchaseErrorMessage {
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
                    viewModel.purchaseBuilding(purchasableBuilding)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(purchasableBuilding.name)
                            .font(.headline)

                        Text("Type: \(purchasableBuilding.type.rawValue)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(String(format: "Cost: $%.2f", purchasableBuilding.cost))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .disabled(viewModel.isPurchasing || viewModel.selectedEmptySlotIndex == nil)
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
            prospectButton(title: "Prospect Stone Quarry", resourceType: .quarry)
        }
    }

    private func prospectButton(title: String, resourceType: ResourceType) -> some View {
        Button {
            viewModel.startProspecting(resourceType)
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
        .disabled(viewModel.isPurchasing || viewModel.selectedEmptySlotIndex == nil)
    }
}

#Preview {
    NavigationStack {
        OperationsView(userID: "demo-user-id-12345")
    }
}
