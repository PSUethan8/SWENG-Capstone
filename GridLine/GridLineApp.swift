//
//  GridLineApp.swift
//  GridLine
//
//  Created by Kenton & Ethan.
//

import SwiftUI

@main
@MainActor
struct GridlineApp: App {

    @StateObject private var trackingViewModel = TrackingViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(trackingViewModel)
        }
    }
}
