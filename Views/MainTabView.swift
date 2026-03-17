//
//  MainTabView.swift
//  Boardroom Tycoon
//
//  Tab-based root navigation: Dashboard, Operations, Market, Portfolio, Profile.
//

import SwiftUI

struct MainTabView: View {
    let userID: String
    @State private var selectedTab: Tab = .dashboard

    enum Tab: String, CaseIterable {
        case dashboard = "Dashboard"
        case operations = "Operations"
        case market = "Market"
        case portfolio = "Portfolio"
        case profile = "Profile"

        var icon: String {
            switch self {
            case .dashboard: return "square.grid.2x2.fill"
            case .operations: return "building.2.fill"
            case .market: return "cart.fill"
            case .portfolio: return "chart.pie.fill"
            case .profile: return "person.fill"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView(userID: userID, selectedTab: $selectedTab)
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
            }
            .tabItem { tabLabel(.market) }
            .tag(Tab.market)

            NavigationStack {
                PortfolioView(userID: userID)
            }
            .tabItem { tabLabel(.portfolio) }
            .tag(Tab.portfolio)

            NavigationStack {
                ProfileView(userID: userID)
            }
            .tabItem { tabLabel(.profile) }
            .tag(Tab.profile)
        }
        .tint(AppTheme.accent)
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(AppTheme.tabBarBackground)
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }

    private func tabLabel(_ tab: Tab) -> Label<Text, Image> {
        Label(tab.rawValue, systemImage: tab.icon)
    }
}

#Preview {
    MainTabView(userID: "preview-user-id")
}
