//
//  DashboardCard.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/11/26.
//

import SwiftUI

struct DashboardCard<Destination: View>: View {
    let title: String
    let systemImage: String
    let destination: Destination

    var body: some View {
        NavigationLink(destination: destination.navigationTitle(title)) {
            VStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 28))

                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        DashboardCard(
            title: "Operations",
            systemImage: "gearshape",
            destination: OperationsView()
        )
        .padding()
    }
}
