//
//  MainTabView.swift
//  Boardroom Tycoon
//
//  Tab-based root navigation: Dashboard, Operations, Market, Portfolio, Profile.
//

import SwiftUI

struct MainTabView: View {
    let userID: String
    @StateObject private var mentionBanner: ChatMentionBannerController
    @StateObject private var chatNav = ChatNavigationCoordinator()
    @State private var selectedTab: Tab = .dashboard

    init(userID: String) {
        self.userID = userID
        _mentionBanner = StateObject(wrappedValue: ChatMentionBannerController(userId: userID))
    }

    enum Tab: String, CaseIterable {
        case dashboard = "Dashboard"
        case operations = "Operations"
        case market = "Market"
        case inventory = "Inventory"
        case profile = "Profile"

        var icon: String {
            switch self {
            case .dashboard: return "square.grid.2x2.fill"
            case .operations: return "building.2.fill"
            case .market: return "cart.fill"
            case .inventory: return "shippingbox.fill"
            case .profile: return "person.fill"
            }
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    DashboardView(userID: userID, selectedTab: $selectedTab)
                        .chatToolbar(userID: userID, hostTab: .dashboard)
                }
                .tabItem { tabLabel(.dashboard) }
                .tag(Tab.dashboard)

                NavigationStack {
                    OperationsView(userID: userID)
                }
                .tabItem { tabLabel(.operations) }
                .tag(Tab.operations)

                NavigationStack {
                    MarketHubView(userID: userID)
                        .chatToolbar(userID: userID, hostTab: .market)
                }
                .tabItem { tabLabel(.market) }
                .tag(Tab.market)

                NavigationStack {
                    InventoryView(userID: userID)
                        .chatToolbar(userID: userID, hostTab: .inventory)
                }
                .tabItem { tabLabel(.inventory) }
                .tag(Tab.inventory)

                NavigationStack {
                    ProfileView(userID: userID)
                }
                .tabItem { tabLabel(.profile) }
                .tag(Tab.profile)
            }
            .tint(AppTheme.accent)

            if let payload = mentionBanner.activeBanner {
                ChatMentionTopBannerView(
                    controller: mentionBanner,
                    payload: payload,
                    onOpenMention: {
                        guard chatNav.openChatFromMention(payload, currentUserId: userID) else { return }
                        mentionBanner.dismissActiveBanner(userInitiated: true)
                        selectedTab = ChatNavigationCoordinator.chatHostTab
                    }
                )
                .padding(.horizontal, AppTheme.horizontalPadding)
                .padding(.top, 6)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .environmentObject(chatNav)
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: mentionBanner.activeBanner?.documentId)
        .onAppear {
            mentionBanner.start()
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(AppTheme.tabBarBackground)
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
        .onDisappear {
            mentionBanner.stop()
        }
    }

    private func tabLabel(_ tab: Tab) -> Label<Text, Image> {
        Label(tab.rawValue, systemImage: tab.icon)
    }
}

#Preview {
    MainTabView(userID: "preview-user-id")
}
