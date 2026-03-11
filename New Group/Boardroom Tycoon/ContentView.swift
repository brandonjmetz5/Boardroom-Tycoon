//
//  ContentView.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/11/26.
//

import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @State private var userID: String?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            if isLoading {
                ProgressView("Signing in...")
                    .controlSize(.large)
            } else if let errorMessage {
                Text("Authentication Failed")
                    .font(.title2)
                    .bold()

                Text(errorMessage)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            } else if let userID {
                VStack(spacing: 12) {
                    Text("Boardroom Tycoon")
                        .font(.largeTitle)
                        .bold()

                    Text("Authenticated Successfully")
                        .font(.headline)

                    Text("Player ID")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(userID)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
            } else {
                Text("No user found.")
            }
        }
        .padding()
       // .onAppear {
       //     signInAnonymouslyIfNeeded()
       // }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                signInAnonymouslyIfNeeded()
            }
        }
        /// This loading sign in spinner was added for visual testing. I wanted to make sure that the user knows that app isnt slow to launch but simply signing in, can later add some sort of Gamelogo UI movement viual to mask the authentication process!
    }

    private func signInAnonymouslyIfNeeded() {
        if let currentUser = Auth.auth().currentUser {
            self.userID = currentUser.uid
            self.isLoading = false
            return
        }

        Auth.auth().signInAnonymously { authResult, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    return
                }

                self.userID = authResult?.user.uid
                self.isLoading = false
            }
        }
    }
}

#Preview {
    ContentView()
}
