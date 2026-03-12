//
//  AppNotification.swift
//  Boardroom Tycoon
//
//  Created by brandon metz on 3/12/26.
//

import Foundation

struct AppNotification: Identifiable {
    let id: String
    let title: String
    let message: String
    let createdAt: Date
    let isRead: Bool
}
