//
//  OperationsView.swift
//  Boardroom Tycoon
//
//  Tactical operations console for production, slots, and expansion.
//

import SwiftUI

struct OperationsView: View {
    let userID: String

    @StateObject private var viewModel: OperationsViewModel

    init(userID: String) {
        self.userID = userID
        _viewModel = StateObject(wrappedValue: OperationsViewModel(userID: userID))
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            Group {
                if viewModel.isLoading {
                    VStack(spacing: 14) {
                        ProgressView()
                            .scaleEffect(1.15)
                            .tint(AppTheme.accent)
                        Text("Synchronizing operations network...")
                            .font(AppTheme.caption())
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                } else if let error = viewModel.loadingErrorMessage {
                    OpsPanel(title: "System Fault", icon: "exclamationmark.triangle.fill", tone: .priority) {
                        OpsAlertRow(icon: "wifi.exclamationmark", title: "Failed to load operations", detail: error, tone: .danger)
                    }
                    .padding(.horizontal, AppTheme.horizontalPadding)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            commandHeaderPanel
                            operationsSnapshotPanel
                            slotsRosterPanel
                        }
                        .padding(.horizontal, AppTheme.horizontalPadding)
                        .padding(.top, 12)
                        .padding(.bottom, 26)
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
        .onAppear { viewModel.loadData() }
        .sheet(isPresented: Binding(
            get: { viewModel.showPurchaseSheet },
            set: { viewModel.showPurchaseSheet = $0 }
        )) {
            purchaseSheetView
        }
    }

    // MARK: - Panel sections

    private var commandHeaderPanel: some View {
        OpsPanel(title: "Operations Command", icon: "antenna.radiowaves.left.and.right", tone: .priority) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Industrial Control Console")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Monitor production lines, prospecting assignments, and slot utilization.")
                        .font(AppTheme.caption())
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                Text(alertSummaryText)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(alertSummaryColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(alertSummaryColor.opacity(0.15)))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(alertSummaryColor.opacity(0.5), lineWidth: 1))
            }
        }
    }

    private var alertSummaryText: String {
        if viewModel.readyCount > 0 { return "\(viewModel.readyCount) READY FOR COLLECTION" }
        if viewModel.producingCount == 0 { return "PRODUCTION IDLE" }
        return "LINES ACTIVE"
    }

    private var alertSummaryColor: Color {
        if viewModel.readyCount > 0 { return AppTheme.chipReady }
        if viewModel.producingCount == 0 { return AppTheme.chipNegative }
        return AppTheme.chipProducing
    }

    private var operationsSnapshotPanel: some View {
        OpsPanel(title: "System Snapshot", icon: "gauge.with.dots.needle.67percent") {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    OpsStatTile(label: "SLOTS", value: "\(viewModel.usedSlotsCount)/\(viewModel.totalSlotsCount)", emphasis: .normal)
                    OpsStatTile(label: "PRODUCING", value: "\(viewModel.producingCount)", emphasis: .warning)
                    OpsStatTile(label: "READY", value: "\(viewModel.readyCount)", emphasis: .positive)
                    OpsStatTile(label: "LISTED", value: "\(viewModel.listedCount)", emphasis: .neutral)
                }

                if let purchaseErrorMessage = viewModel.purchaseErrorMessage {
                    OpsAlertRow(icon: "exclamationmark.triangle.fill", title: "Recent Action Issue", detail: purchaseErrorMessage, tone: .danger)
                }
            }
        }
    }

    private var slotsRosterPanel: some View {
        OpsPanel(title: "Slot Roster", icon: "square.grid.3x1.folder.fill") {
            LazyVStack(spacing: 12) {
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
    }

    // MARK: - Slot cards

    private func buildingCard(for building: Building) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            NavigationLink(destination: destinationView(for: building)) {
                ZStack(alignment: .leading) {
                    Image(viewModel.buildingAssetName(for: building))
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, minHeight: 176, maxHeight: 176)
                        .clipped()
                        .opacity(0.88)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            OpsChip(title: viewModel.buildingStatusText(for: building, now: context.date), color: statusColor(for: viewModel.buildingStatus(for: building, now: context.date)))
                            Spacer()
                            Text(viewModel.buildingFamilyLabel(for: building).uppercased())
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppTheme.textPrimary)
                                .shadow(color: .black.opacity(0.55), radius: 2, x: 0, y: 1)
                        }

                        Spacer()

                        VStack(alignment: .leading, spacing: 6) {
                            Text(building.name)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)
                                .lineLimit(2)
                                .shadow(color: .black.opacity(0.55), radius: 3, x: 0, y: 1)

                            Text(viewModel.buildingDetailText(for: building, now: context.date))
                                .font(AppTheme.caption())
                                .foregroundStyle(AppTheme.textPrimary)
                                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)

                            if viewModel.buildingStatus(for: building, now: context.date) == .idle,
                               let hint = viewModel.productionInputHint(for: building) {
                                Text("INPUT BOTTLENECK: \(hint.uppercased())")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(AppTheme.chipNegative)
                                    .shadow(color: .black.opacity(0.45), radius: 2, x: 0, y: 1)
                            }
                        }
                    }
                    .padding(16)
                }
                .frame(maxWidth: .infinity, minHeight: 176, maxHeight: 176)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private func destinationView(for building: Building) -> AnyView {
        if building.type == .mine || building.type == .rig || building.type == .quarry {
            return AnyView(ExtractorDetailView(userID: userID, building: building))
        } else if building.type == .researchAndDevelopment {
            return AnyView(ResearchAndDevelopmentView(userID: userID, building: building))
        } else {
            return AnyView(BuildingDetailView(userID: userID, building: building))
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
                        .frame(maxWidth: .infinity, minHeight: 176, maxHeight: 176)
                        .clipped()
                        .opacity(0.88)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            OpsChip(
                                title: job.endsAt <= context.date ? "READY" : "PROSPECTING",
                                color: job.endsAt <= context.date ? AppTheme.chipReady : AppTheme.chipProspecting
                            )
                            Spacer()
                        }

                        Spacer()

                        Text(viewModel.prospectingLabel(for: job.resourceType))
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(2)
                            .shadow(color: .black.opacity(0.55), radius: 3, x: 0, y: 1)

                        Text(job.endsAt <= context.date ? "Result ready. Tap to reveal." : "ETA \(viewModel.formattedTimeRemaining(until: job.endsAt, now: context.date))")
                            .font(AppTheme.caption())
                            .foregroundStyle(AppTheme.textPrimary)
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    }
                    .padding(16)
                }
                .frame(maxWidth: .infinity, minHeight: 176, maxHeight: 176)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
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
                    .frame(maxWidth: .infinity, minHeight: 176, maxHeight: 176)
                    .clipped()
                    .opacity(0.88)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        OpsChip(title: "AVAILABLE", color: AppTheme.chipAvailable)
                        Spacer()
                    }
                    Spacer()
                    Text("Open Slot \(slotIndex + 1)")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .shadow(color: .black.opacity(0.55), radius: 3, x: 0, y: 1)
                    Text("Deploy building or launch prospecting mission")
                        .font(AppTheme.caption())
                        .foregroundStyle(AppTheme.textPrimary)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity, minHeight: 176, maxHeight: 176)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func statusColor(for status: BuildingStatusDisplay) -> Color {
        switch status {
        case .listed: return AppTheme.chipListed
        case .ready: return AppTheme.chipReady
        case .producing: return AppTheme.chipProducing
        case .idle: return AppTheme.chipIdle
        }
    }

    // MARK: - Purchase sheet

    private var purchaseSheetView: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if let purchaseErrorMessage = viewModel.purchaseErrorMessage {
                            OpsAlertRow(icon: "exclamationmark.triangle.fill", title: "Action failed", detail: purchaseErrorMessage, tone: .danger)
                        }

                        OpsPanel(title: "Buy Building", icon: "building.2.fill", tone: .priority) {
                            VStack(spacing: 8) {
                                ForEach(BuildingCatalog.purchasableBuildings) { p in
                                    Button {
                                        viewModel.purchaseBuilding(p)
                                    } label: {
                                        HStack(alignment: .top) {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(p.name)
                                                    .font(AppTheme.bodyMedium())
                                                    .foregroundStyle(AppTheme.textPrimary)
                                                Text("Type: \(p.type.rawValue)")
                                                    .font(AppTheme.caption())
                                                    .foregroundStyle(AppTheme.textSecondary)
                                            }
                                            Spacer()
                                            Text(String(format: "$%.0f", p.cost))
                                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                                .foregroundStyle(AppTheme.accent)
                                        }
                                        .padding(10)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.surfaceAlt.opacity(0.5)))
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(viewModel.isPurchasing || viewModel.selectedEmptySlotIndex == nil)
                                }
                            }
                        }

                        OpsPanel(title: "Prospect Resource Site", icon: "scope") {
                            VStack(spacing: 8) {
                                prospectButton("Prospect Gold Mine", .gold)
                                prospectButton("Prospect Silver Mine", .silver)
                                prospectButton("Prospect Diamond Mine", .diamond)
                                prospectButton("Prospect Oil Rig", .oil)
                                prospectButton("Prospect Coal Mine", .coal)
                                prospectButton("Prospect Iron Mine", .iron)
                                prospectButton("Prospect Sand Quarry", .sandQuarry)
                                prospectButton("Prospect Stone Quarry", .stoneQuarry)
                                prospectButton("Prospect Gravel Quarry", .gravelQuarry)
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.horizontalPadding)
                    .padding(.top, 14)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Use Empty Slot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { viewModel.closePurchaseSheet() }
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .overlay {
                if viewModel.isPurchasing {
                    ProgressView("Processing...")
                        .padding(18)
                        .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border, lineWidth: 1))
                }
            }
        }
    }

    private func prospectButton(_ title: String, _ resourceType: ResourceType) -> some View {
        Button {
            viewModel.startProspecting(resourceType)
        } label: {
            HStack {
                Text(title)
                    .font(AppTheme.bodyMedium())
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text("1 SLOT")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.surfaceAlt.opacity(0.5)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isPurchasing || viewModel.selectedEmptySlotIndex == nil)
    }
}

// MARK: - Reusable operations UI

private enum OpsPanelTone {
    case normal
    case priority
}

private struct OpsPanel<Content: View>: View {
    let title: String
    let icon: String
    let tone: OpsPanelTone
    private let content: Content

    init(
        title: String,
        icon: String,
        tone: OpsPanelTone = .normal,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.tone = tone
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(tone == .priority ? AppTheme.accent : AppTheme.textSecondary)
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)
                Rectangle().fill(AppTheme.border).frame(height: 1)
            }
            content
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(AppTheme.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(tone == .priority ? AppTheme.accent.opacity(0.45) : AppTheme.border, lineWidth: 1)
        )
    }
}

private struct OpsChip: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(color.opacity(0.92)))
    }
}

private struct OpsStatTile: View {
    enum Emphasis {
        case normal
        case positive
        case warning
        case neutral
    }

    let label: String
    let value: String
    let emphasis: Emphasis

    private var color: Color {
        switch emphasis {
        case .normal: return AppTheme.accent
        case .positive: return AppTheme.chipReady
        case .warning: return AppTheme.chipProducing
        case .neutral: return AppTheme.textSecondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.textTertiary)
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.surfaceAlt.opacity(0.62)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border, lineWidth: 1))
    }
}

private struct OpsAlertRow: View {
    enum Tone {
        case neutral
        case danger
    }

    let icon: String
    let title: String
    let detail: String
    let tone: Tone

    private var color: Color {
        switch tone {
        case .neutral: return AppTheme.textSecondary
        case .danger: return AppTheme.chipNegative
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTheme.captionMedium())
                    .foregroundStyle(AppTheme.textPrimary)
                Text(detail)
                    .font(AppTheme.caption())
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.surfaceAlt.opacity(0.45)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.28), lineWidth: 1))
    }
}

#Preview {
    NavigationStack {
        OperationsView(userID: "demo-user-id-12345")
    }
}
