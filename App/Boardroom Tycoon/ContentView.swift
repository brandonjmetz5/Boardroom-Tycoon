//
//  ContentView.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/11/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            Group {
                if viewModel.isLoading {
                    VStack(spacing: 16) {
                        ProgressView("Signing in...")
                            .controlSize(.large)
                            .tint(.white)
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Signing in...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                } else if let errorMessage = viewModel.errorMessage {
                    VStack(spacing: 12) {
                        Text("Authentication Failed")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)

                        Text(errorMessage)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(AppTheme.textError)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(24)
                } else if let userID = viewModel.userID {
                    NavigationStack {
                        HomeView(userID: userID)
                    }
                } else {
                    Text("No user found.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding()
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                viewModel.signInAnonymouslyIfNeeded()
            }
        }
    }
}

#Preview {
    ContentView()
}
