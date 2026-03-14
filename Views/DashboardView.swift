//
//  DashboardView.swift
//  Boardroom Tycoon
//
//  Headquarters: command-center dashboard with key metrics and department access.
//

import SwiftUI

struct DashboardView: View {
    let userID: String
    @Binding var selectedTab: MainTabView.Tab

    @StateObject private var viewModel: HomeViewModel

    init(userID: String, selectedTab: Binding<MainTabView.Tab>) {
        self.userID = userID
        _selectedTab = selectedTab
        _viewModel = StateObject(wrappedValue: HomeViewModel(userID: userID))
    }

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            if viewModel.isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(AppTheme.accent)
                    Text("Connecting to headquarters...")
                        .font(AppTheme.caption())
                        .foregroundStyle(AppTheme.textSecondary)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        headerSection
                        treasurySection
                        operationsOverviewSection
                        fieldOpsSection
                        inventorySection
                        departmentsSection
                    }
                    .padding(.horizontal, AppTheme.horizontalPadding)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Headquarters")
                    .font(AppTheme.titleMedium())
                    .foregroundStyle(AppTheme.textPrimary)
            }
        }
        .onAppear {
            viewModel.loadData()
        }
    }

    // MARK: - HQ header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "building.2.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(AppTheme.accent)
                Text("Command Center")
                    .font(AppTheme.titleLarge())
                    .foregroundStyle(AppTheme.textPrimary)
            }
            Text("Overview of your operations and resources.")
                .font(AppTheme.caption())
                .foregroundStyle(AppTheme.textTertiary)
        }
        .padding(.bottom, AppTheme.sectionSpacing)
    }

    // MARK: - Treasury (cash, level, slots)

    private var treasurySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Treasury", icon: "dollarsign.circle.fill")

            if let profile = viewModel.profile {
                HStack(spacing: 0) {
                    treasuryStat(value: String(format: "$%.0f", profile.cash), label: "Liquid assets")
                    Rectangle()
                        .fill(AppTheme.border)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                        .padding(.vertical, 8)
                    treasuryStat(value: "\(profile.level)", label: "Executive level")
                    Rectangle()
                        .fill(AppTheme.border)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                        .padding(.vertical, 8)
                    treasuryStat(value: "\(viewModel.usedSlotsCount)/\(viewModel.totalSlotsCount)", label: "Slots used")
                }
                .padding(AppTheme.cardPadding)
                .frame(maxWidth: .infinity)
                .appCard()
            } else if viewModel.profileErrorMessage != nil {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppTheme.textError)
                    Text("Unable to load treasury data")
                        .font(AppTheme.caption())
                        .foregroundStyle(AppTheme.textError)
                }
                .padding(AppTheme.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .appCard()
            } else {
                Text("—")
                    .font(AppTheme.body())
                    .foregroundStyle(AppTheme.textMuted)
                    .padding(AppTheme.cardPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appCard()
            }
        }
        .padding(.bottom, AppTheme.sectionSpacing)
    }

    private func treasuryStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppTheme.monoNumber())
                .foregroundStyle(AppTheme.accent)
            Text(label)
                .font(AppTheme.captionMedium())
                .foregroundStyle(AppTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Operations overview (producing, ready, listed)

    private var operationsOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Operations", icon: "gearshape.2.fill")

            HStack(spacing: 12) {
                opsPill(value: "\(viewModel.producingCount)", label: "Producing", color: AppTheme.chipProducing)
                opsPill(value: "\(viewModel.readyCount)", label: "Ready", color: AppTheme.chipReady)
                opsPill(value: "\(viewModel.listedCount)", label: "Listed", color: AppTheme.chipListed)
            }
            .padding(AppTheme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appCard()

            if viewModel.usedSlotsCount == 0 && (viewModel.profile?.buildingSlotCount ?? 0) > 0 {
                Button {
                    selectedTab = .operations
                } label: {
                    HStack {
                        Text("Deploy assets in Operations")
                            .font(AppTheme.captionMedium())
                            .foregroundStyle(AppTheme.accent)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)
                    }
                }
                .padding(.top, 4)
            } else if viewModel.readyCount > 0 {
                Button {
                    selectedTab = .operations
                } label: {
                    HStack {
                        Text("\(viewModel.readyCount) ready to collect")
                            .font(AppTheme.captionMedium())
                            .foregroundStyle(AppTheme.chipReady)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.chipReady)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.bottom, AppTheme.sectionSpacing)
    }

    private func opsPill(value: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(AppTheme.monoNumber())
                .foregroundStyle(color)
            Text(label)
                .font(AppTheme.captionMedium())
                .foregroundStyle(AppTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Field ops (prospecting)

    private var fieldOpsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Field operations", icon: "magnifyingglass")

            if viewModel.isLoadingProspecting {
                HStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.9)
                        .tint(AppTheme.accent)
                    Text("Checking field reports...")
                        .font(AppTheme.caption())
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(AppTheme.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .appCard()
            } else if let err = viewModel.prospectingErrorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppTheme.textError)
                    Text(err)
                        .font(AppTheme.caption())
                        .foregroundStyle(AppTheme.textError)
                }
                .padding(AppTheme.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .appCard()
            } else if let job = viewModel.activeProspectingJob {
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(viewModel.prospectingLabel(for: job.resourceType))
                                .font(AppTheme.bodyMedium())
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            if job.isRevealed {
                                statusBadge("Result ready", color: AppTheme.chipReady)
                            } else if job.endsAt <= ctx.date {
                                statusBadge("Ready to reveal", color: AppTheme.chipReady)
                            } else {
                                Text(viewModel.formattedTimeRemaining(until: job.endsAt, now: ctx.date))
                                    .font(AppTheme.monoNumber())
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                        if !job.isRevealed && job.endsAt > ctx.date {
                            Text("Prospecting in progress. Report available when timer completes.")
                                .font(AppTheme.caption())
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                    }
                    .padding(AppTheme.cardPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appCard()
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No active field assignment")
                        .font(AppTheme.bodyMedium())
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Assign prospecting from an empty slot in Operations.")
                        .font(AppTheme.caption())
                        .foregroundStyle(AppTheme.textTertiary)
                    Button {
                        selectedTab = .operations
                    } label: {
                        Text("Go to Operations")
                            .font(AppTheme.captionMedium())
                            .foregroundStyle(AppTheme.accent)
                    }
                    .padding(.top, 4)
                }
                .padding(AppTheme.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .appCard()
            }
        }
        .padding(.bottom, AppTheme.sectionSpacing)
    }

    private func statusBadge(_ title: String, color: Color) -> some View {
        Text(title)
            .font(AppTheme.captionMedium())
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.2)))
    }

    // MARK: - Inventory

    private var inventorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Inventory", icon: "shippingbox.fill")

            if viewModel.inventoryItems.isEmpty {
                Text("No items yet. Produce or acquire resources to see them here.")
                    .font(AppTheme.caption())
                    .foregroundStyle(AppTheme.textTertiary)
                    .padding(AppTheme.cardPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appCard()
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(viewModel.inventoryItems) { inv in
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(inv.item.name)
                                    .font(AppTheme.bodyMedium())
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text(inv.item.category.rawValue)
                                    .font(AppTheme.captionMedium())
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(viewModel.formattedQuantity(for: inv))
                                    .font(AppTheme.monoNumber())
                                    .foregroundStyle(AppTheme.accent)
                                if let value = ItemValueCatalog.value(quantity: inv.quantity, itemId: inv.item.id) {
                                    Text(String(format: "≈ $%.2f", value))
                                        .font(AppTheme.captionMedium())
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        if inv.id != viewModel.inventoryItems.last?.id {
                            Rectangle()
                                .fill(AppTheme.border)
                                .frame(height: 1)
                        }
                    }
                    if viewModel.totalInventoryValue > 0 {
                        Rectangle()
                            .fill(AppTheme.border)
                            .frame(height: 1)
                        HStack {
                            Text("Total value")
                                .font(AppTheme.bodyMedium())
                                .foregroundStyle(AppTheme.textSecondary)
                            Spacer()
                            Text(String(format: "$%.2f", viewModel.totalInventoryValue))
                                .font(AppTheme.monoNumber())
                                .foregroundStyle(AppTheme.accent)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                    }
                }
                .padding(AppTheme.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .appCard()
            }
        }
        .padding(.bottom, AppTheme.sectionSpacing)
    }

    // MARK: - Departments

    private var departmentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Departments", icon: "square.grid.2x2.fill")

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                departmentTile(.operations, title: "Operations", subtitle: "Buildings & production", icon: "building.2.fill")
                departmentTile(.market, title: "Market", subtitle: "Buy & sell mines", icon: "cart.fill")
                departmentTile(.portfolio, title: "Portfolio", subtitle: "Stocks", icon: "chart.pie.fill")
                departmentTile(.profile, title: "Profile", subtitle: "Account & stats", icon: "person.fill")
            }
        }
    }

    private func sectionLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.accent)
            Text(title)
                .font(AppTheme.titleSmall())
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(.bottom, 8)
    }

    private func departmentTile(_ tab: MainTabView.Tab, title: String, subtitle: String, icon: String) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(AppTheme.accent)
                Text(title)
                    .font(AppTheme.bodyMedium())
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(AppTheme.caption())
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .padding(AppTheme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appCard()
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        DashboardView(userID: "preview-user-id", selectedTab: .constant(.dashboard))
    }
}
