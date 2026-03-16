//
//  ResearchAndDevelopmentView.swift
//  Boardroom Tycoon
//
//  Detail screen for the Research & Development building.
//

import SwiftUI
import Combine

struct ResearchAndDevelopmentView: View {
    let userID: String
    let building: Building

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ResearchAndDevelopmentViewModel

    init(userID: String, building: Building) {
        self.userID = userID
        self.building = building
        _viewModel = StateObject(wrappedValue: ResearchAndDevelopmentViewModel(userID: userID, building: building))
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView("Loading R&D...")
                    .controlSize(.large)
                    .tint(AppTheme.accent)
                    .foregroundStyle(AppTheme.textPrimary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                        headerSection
                        researchCycleSection
                        resourceListSection
                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AppTheme.textError)
                        }
                    }
                    .padding(.horizontal, AppTheme.horizontalPadding)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("R&D")
                    .font(AppTheme.titleMedium())
                    .foregroundStyle(AppTheme.textPrimary)
            }
        }
        .onAppear {
            viewModel.loadData()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(building.name)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            HStack(spacing: 12) {
                Text("Level \(building.level)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                if let profile = viewModel.profile {
                    Text(String(format: "Research Points: %d", profile.researchPoints))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    private var researchCycleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Research Cycle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
            }

            if viewModel.isWorking {
                ProgressView()
                    .tint(AppTheme.accent)
            }

            if let profile = viewModel.profile {
                Text(String(format: "Available Research Points: %d", profile.researchPoints))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            HStack(spacing: 10) {
                Button {
                    viewModel.startResearchCycle()
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Research")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isWorking)

                Button {
                    viewModel.collectResearch()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Collect")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(AppTheme.chipReady)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isWorking)
            }
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    private var resourceListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Resource Quality")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
            }

            HStack(spacing: 8) {
                Text("Points to apply:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textTertiary)
                TextField("Amount", text: $viewModel.pointsToApplyText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
            }

            ForEach(viewModel.items) { item in
                resourceRow(for: item)
            }
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    private func resourceRow(for item: Item) -> some View {
        let quality = viewModel.currentQuality(for: item)
        let level = quality?.qualityLevel ?? 1
        let progress = quality?.currentResearchPoints ?? 0
        let required = viewModel.requiredPoints(forLevel: level)

        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Quality Q\(level)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                Text("Progress: \(progress)/\(required)")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            Spacer()
            Button {
                viewModel.applyResearchPoints(to: item)
            } label: {
                Text("Apply")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(AppTheme.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isWorking)
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    NavigationStack {
        ResearchAndDevelopmentView(
            userID: "demo-user-id-12345",
            building: Building(
                id: "building-research-and-development",
                name: "Research & Development",
                type: .researchAndDevelopment,
                level: 1,
                capacity: 1,
                slotIndex: 0,
                resourceType: nil,
                abundance: nil,
                isStarterMine: false,
                isProducing: false,
                productionStartedAt: nil,
                productionEndsAt: nil,
                pendingOutputQuantity: nil,
                pendingOutputItemId: nil,
                pendingOutputItemName: nil,
                pendingOutputQuality: nil,
                isListedOnMarket: false,
                marketListingID: nil
            )
        )
    }
}

