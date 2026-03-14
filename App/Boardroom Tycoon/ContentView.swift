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
        Group {
            if viewModel.isLoading {
                ProgressView("Signing in...")
                    .controlSize(.large)
            } else if let errorMessage = viewModel.errorMessage {
                VStack(spacing: 12) {
                    Text("Authentication Failed")
                        .font(.title2)
                        .bold()

                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
            } else if let userID = viewModel.userID {
                NavigationStack {
                    HomeView(userID: userID)
                }
            } else {
                Text("No user found.")
                    .padding()
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
