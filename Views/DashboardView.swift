//
//  DashboardView.swift
//  Boardroom Tycoon
//
//  Unified command-center dashboard with brighter integrated rails.
//

import SwiftUI

struct DashboardView: View {
    let userID: String
    @Binding var selectedTab: MainTabView.Tab

    @StateObject private var viewModel: HomeViewModel
    @State private var isSideMenuOpen = false
    @State private var sideMenuDragX: CGFloat = 0

    init(userID: String, selectedTab: Binding<MainTabView.Tab>) {
        self.userID = userID
        _selectedTab = selectedTab
        _viewModel = StateObject(wrappedValue: HomeViewModel(userID: userID))
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            LinearGradient(
                colors: [AppTheme.surface.opacity(0.12), Color.clear, AppTheme.surface.opacity(0.12)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if viewModel.isLoading {
                VStack(spacing: 14) {
                    ProgressView().scaleEffect(1.15).tint(AppTheme.accent)
                    Text("Booting command center...")
                        .font(AppTheme.caption())
                        .foregroundStyle(AppTheme.textSecondary)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        commandHeaderPanel
                        resourceStrip
                        operationsPanel
                        assetsPanel
                        alertsPanel
                        progressionPanel
                        marketSnapshotPanel
                        quickActionsPanel
                    }
                    .padding(.horizontal, AppTheme.horizontalPadding)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
        }
        .overlay(alignment: .leading) {
            sideMenuOverlay
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        isSideMenuOpen.toggle()
                        sideMenuDragX = 0
                    }
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Menu")
            }
            ToolbarItem(placement: .principal) {
                Text("Headquarters")
                    .font(AppTheme.titleMedium())
                    .foregroundStyle(AppTheme.textPrimary)
            }
        }
        .onAppear { viewModel.loadData() }
    }

    private var sideMenuOverlay: some View {
        GeometryReader { geo in
            let menuWidth = min(320.0, geo.size.width * 0.82)
            let maxDragClose = menuWidth
            let drag = isSideMenuOpen ? max(0, sideMenuDragX) : menuWidth
            let offsetX = isSideMenuOpen ? (-drag) : (-(menuWidth + 40))

            ZStack(alignment: .leading) {
                if isSideMenuOpen {
                    Color.black
                        .opacity(0.45)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                                isSideMenuOpen = false
                                sideMenuDragX = 0
                            }
                        }
                        .transition(.opacity)
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 28, height: 28)
                            .background(AppTheme.accent.opacity(0.14))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("COMMAND MENU")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppTheme.textSecondary)
                            Text("Secondary navigation")
                                .font(AppTheme.caption())
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                                isSideMenuOpen = false
                                sideMenuDragX = 0
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(AppTheme.textSecondary)
                                .frame(width: 32, height: 32)
                                .background(AppTheme.surfaceAlt.opacity(0.45))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    Rectangle()
                        .fill(AppTheme.border)
                        .frame(height: 1)

                    VStack(spacing: 10) {
                        NavigationLink {
                            LeaderboardsView(userID: userID)
                        } label: {
                            sideMenuRow(title: "Leaderboards", subtitle: "Company value rankings", systemImage: "trophy.fill", tint: AppTheme.chipProducing)
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(TapGesture().onEnded {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                                isSideMenuOpen = false
                                sideMenuDragX = 0
                            }
                        })

                        NavigationLink {
                            EncyclopediaView()
                        } label: {
                            sideMenuRow(title: "Encyclopedia", subtitle: "Recipes and item knowledge", systemImage: "book.fill", tint: AppTheme.chipAvailable)
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(TapGesture().onEnded {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                                isSideMenuOpen = false
                                sideMenuDragX = 0
                            }
                        })

                        NavigationLink {
                            TutorialHubView()
                        } label: {
                            sideMenuRow(title: "Tutorial", subtitle: "How to play", systemImage: "graduationcap.fill", tint: AppTheme.accent)
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(TapGesture().onEnded {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                                isSideMenuOpen = false
                                sideMenuDragX = 0
                            }
                        })

                        NavigationLink {
                            HelpCenterView()
                        } label: {
                            sideMenuRow(title: "Help", subtitle: "Support and FAQ", systemImage: "questionmark.circle.fill", tint: AppTheme.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(TapGesture().onEnded {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                                isSideMenuOpen = false
                                sideMenuDragX = 0
                            }
                        })
                    }

                    Spacer(minLength: 0)
                }
                .padding(14)
                .frame(width: menuWidth, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppTheme.surface.opacity(0.92))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(AppTheme.border.opacity(0.95), lineWidth: 1)
                        )
                )
                .offset(x: offsetX)
                .padding(.vertical, 8)
                .gesture(
                    DragGesture(minimumDistance: 6)
                        .onChanged { value in
                            guard isSideMenuOpen else { return }
                            if value.translation.width < 0 {
                                sideMenuDragX = min(maxDragClose, abs(value.translation.width))
                            } else {
                                sideMenuDragX = 0
                            }
                        }
                        .onEnded { value in
                            guard isSideMenuOpen else { return }
                            let shouldClose = abs(value.translation.width) > (menuWidth * 0.35)
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                                isSideMenuOpen = shouldClose ? false : true
                                sideMenuDragX = 0
                            }
                        }
                )
            }
            .allowsHitTesting(isSideMenuOpen)
        }
    }

    private func sideMenuRow(title: String, subtitle: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AppTheme.bodyMedium())
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(AppTheme.caption())
                    .foregroundStyle(AppTheme.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.textTertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.surfaceAlt.opacity(0.55)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border.opacity(0.95), lineWidth: 1))
    }

    private var commandHeaderPanel: some View {
        CommandRail(title: "Company Command", systemImage: "building.2.crop.circle.fill", tone: .priority) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Boardroom Tycoon")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Executive operations console")
                            .font(AppTheme.caption())
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    statusBadge
                }
                if let p = viewModel.profile {
                    HStack(spacing: 10) {
                        StatTile(label: "LEVEL", value: "\(p.level)", emphasis: .normal)
                        StatTile(label: "XP", value: "\(p.xp)", emphasis: .normal)
                        StatTile(label: "R&D", value: "\(p.researchPoints)", emphasis: .positive)
                    }
                }
            }
        }
    }

    private var statusBadge: some View {
        let count = dashboardAlerts.count
        let label = count > 0 ? "\(count) ACTION ITEM\(count == 1 ? "" : "S")" : "SYSTEM STABLE"
        let color = count > 0 ? AppTheme.chipNegative : AppTheme.chipReady
        return Text(label)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.14)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.45), lineWidth: 1))
    }

    private var resourceStrip: some View {
        CommandRail(title: "Treasury Strip", systemImage: "banknote.fill") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    stripTile("Cash", NumberFormatting.currency(viewModel.profile?.cash ?? 0, fractionDigits: 0), AppTheme.accent)
                    stripTile("Inventory", NumberFormatting.currency(viewModel.totalInventoryValue, fractionDigits: 0), AppTheme.chipAvailable)
                    stripTile("Slots", "\(viewModel.usedSlotsCount)/\(viewModel.totalSlotsCount)", AppTheme.chipProspecting)
                    stripTile("Producing", "\(viewModel.producingCount)", AppTheme.chipProducing)
                    stripTile("Ready", "\(viewModel.readyCount)", AppTheme.chipReady)
                    stripTile("Listed", "\(viewModel.listedCount)", AppTheme.chipListed)
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func stripTile(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.textTertiary)
            Text(value)
                .font(AppTheme.monoNumber())
                .foregroundStyle(color)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 9).fill(AppTheme.surfaceAlt.opacity(0.55)))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(AppTheme.border.opacity(0.95), lineWidth: 1))
    }

    private var operationsPanel: some View {
        CommandRail(title: "Operations Matrix", systemImage: "gearshape.2.fill") {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    StatTile(label: "PRODUCING", value: "\(viewModel.producingCount)", emphasis: .normal)
                    StatTile(label: "READY", value: "\(viewModel.readyCount)", emphasis: .positive)
                    StatTile(label: "LISTED", value: "\(viewModel.listedCount)", emphasis: .warning)
                }
                HStack(spacing: 10) {
                    StatTile(label: "BUILDINGS", value: "\(viewModel.buildings.count)", emphasis: .normal)
                    StatTile(label: "CAPACITY", value: "\(viewModel.usedSlotsCount)/\(viewModel.totalSlotsCount)", emphasis: .normal)
                }
                if let profileError = viewModel.profileErrorMessage {
                    AlertRow(icon: "exclamationmark.triangle.fill", title: "Profile load issue", detail: profileError, tone: .danger)
                }
            }
        }
    }

    private var assetsPanel: some View {
        CommandRail(title: "Asset Command", systemImage: "shippingbox.fill") {
            let grouped = Dictionary(grouping: viewModel.buildings, by: { $0.type.rawValue })
            let rows = grouped.keys.sorted().prefix(4)
            if rows.isEmpty {
                AlertRow(icon: "cube.box", title: "No assets deployed", detail: "Acquire or prospect new buildings from Operations.", tone: .neutral)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(rows), id: \.self) { key in
                        HStack {
                            Text(key.uppercased())
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppTheme.textSecondary)
                            Spacer()
                            Text("\(grouped[key]?.count ?? 0)")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppTheme.accent)
                        }
                        .padding(.vertical, 6)
                        if key != rows.last { Divider().overlay(AppTheme.border) }
                    }
                }
            }
        }
    }

    private var alertsPanel: some View {
        CommandRail(title: "Command Alerts", systemImage: "bell.badge.fill", tone: .priority) {
            if dashboardAlerts.isEmpty {
                AlertRow(icon: "checkmark.seal.fill", title: "No critical issues", detail: "Operations are running within normal parameters.", tone: .success)
            } else {
                VStack(spacing: 8) {
                    ForEach(dashboardAlerts) { alert in
                        AlertRow(icon: alert.icon, title: alert.title, detail: alert.detail, tone: alert.tone)
                    }
                }
            }
        }
    }

    private var progressionPanel: some View {
        CommandRail(title: "Expansion Objectives", systemImage: "flag.fill") {
            if let p = viewModel.profile {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Level \(p.level) progression")
                            .font(AppTheme.bodyMedium())
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Text("\(p.xp) XP")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppTheme.accent)
                    }
                    objectiveRow("Increase slot utilization efficiency", complete: viewModel.usedSlotsCount >= max(1, viewModel.totalSlotsCount - 1))
                    objectiveRow("Keep production lines active", complete: viewModel.producingCount > 0)
                    objectiveRow("Maintain liquidity buffer > $10k", complete: p.cash >= 10_000)
                }
            } else {
                AlertRow(icon: "clock.arrow.circlepath", title: "Syncing profile", detail: "Progress objectives will populate after profile sync.", tone: .neutral)
            }
        }
    }

    private func objectiveRow(_ title: String, complete: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: complete ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(complete ? AppTheme.chipReady : AppTheme.textTertiary)
            Text(title)
                .font(AppTheme.caption())
                .foregroundStyle(AppTheme.textSecondary)
            Spacer()
            Text(complete ? "DONE" : "PENDING")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(complete ? AppTheme.chipReady : AppTheme.textTertiary)
        }
    }

    private var marketSnapshotPanel: some View {
        CommandRail(title: "Market Situation", systemImage: "chart.xyaxis.line") {
            VStack(alignment: .leading, spacing: 8) {
                metricRow("Assets listed", "\(viewModel.listedCount)", AppTheme.chipListed)
                metricRow("Inventory liquidity", NumberFormatting.currency(viewModel.totalInventoryValue, fractionDigits: 0), AppTheme.chipAvailable)
                if viewModel.isLoadingProspecting {
                    Text("Prospecting feed syncing...")
                        .font(AppTheme.caption())
                        .foregroundStyle(AppTheme.textSecondary)
                } else if let job = viewModel.activeProspectingJob {
                    Text("Prospecting: \(viewModel.prospectingLabel(for: job.resourceType))")
                        .font(AppTheme.caption())
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    Text("No active prospecting assignment.")
                        .font(AppTheme.caption())
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
    }

    private func metricRow(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(label)
                .font(AppTheme.caption())
                .foregroundStyle(AppTheme.textTertiary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
        }
    }

    private var quickActionsPanel: some View {
        CommandRail(title: "Quick Actions", systemImage: "bolt.fill") {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                TabActionButton(title: "Operations", icon: "gearshape.2.fill", tint: AppTheme.chipProspecting) { selectedTab = .operations }
                TabActionButton(title: "Market Hub", icon: "cart.fill", tint: AppTheme.accent) { selectedTab = .market }
                TabActionButton(title: "Inventory", icon: "shippingbox.fill", tint: AppTheme.chipAvailable) { selectedTab = .inventory }
                TabActionButton(title: "Profile", icon: "person.fill", tint: AppTheme.chipListed) { selectedTab = .profile }
            }
        }
    }

    private var dashboardAlerts: [DashboardAlert] {
        var alerts: [DashboardAlert] = []
        if viewModel.producingCount == 0 {
            alerts.append(.init(icon: "pause.circle.fill", title: "Production idle", detail: "No active production cycles. Start output from Operations.", tone: .danger))
        }
        if viewModel.readyCount > 0 {
            alerts.append(.init(icon: "checkmark.circle.fill", title: "Collection ready", detail: "\(viewModel.readyCount) building(s) are ready to collect.", tone: .success))
        }
        if let job = viewModel.activeProspectingJob {
            if job.isRevealed {
                alerts.append(.init(icon: "sparkles", title: "Prospecting result available", detail: "\(viewModel.prospectingLabel(for: job.resourceType)) report ready.", tone: .warning))
            } else {
                alerts.append(.init(icon: "scope", title: "Prospecting active", detail: "\(viewModel.prospectingLabel(for: job.resourceType)) underway.", tone: .neutral))
            }
        } else if !viewModel.isLoadingProspecting {
            alerts.append(.init(icon: "scope", title: "No active prospecting", detail: "Assign a new prospecting job to discover expansion options.", tone: .neutral))
        }
        return alerts.prefix(4).map { $0 }
    }
}

private enum CommandRailTone {
    case normal
    case priority
}

private struct CommandRail<Content: View>: View {
    let title: String
    let systemImage: String
    var tone: CommandRailTone
    private let content: Content

    init(title: String, systemImage: String, tone: CommandRailTone = .normal, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.tone = tone
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
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
        .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.surface.opacity(0.82)))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(tone == .priority ? AppTheme.accent.opacity(0.32) : AppTheme.border.opacity(0.95), lineWidth: 1)
        )
    }
}

private struct StatTile: View {
    enum Emphasis { case normal, positive, warning }
    let label: String
    let value: String
    var emphasis: Emphasis = .normal

    private var color: Color {
        switch emphasis {
        case .normal: return AppTheme.accent
        case .positive: return AppTheme.chipReady
        case .warning: return AppTheme.chipProducing
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
        .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.surfaceAlt.opacity(0.60)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border.opacity(0.95), lineWidth: 1))
    }
}

private struct AlertRow: View {
    enum Tone { case neutral, success, warning, danger }
    let icon: String
    let title: String
    let detail: String
    let tone: Tone

    private var color: Color {
        switch tone {
        case .neutral: return AppTheme.textSecondary
        case .success: return AppTheme.chipReady
        case .warning: return AppTheme.chipProducing
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
        .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.surfaceAlt.opacity(0.50)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.22), lineWidth: 1))
    }
}

private struct TabActionButton: View {
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.surfaceAlt.opacity(0.58)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(tint.opacity(0.45), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct DashboardAlert: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
    let tone: AlertRow.Tone
}

#Preview {
    NavigationStack {
        DashboardView(userID: "preview-user-id", selectedTab: .constant(.dashboard))
    }
}
