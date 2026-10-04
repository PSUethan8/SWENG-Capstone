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

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(trackingViewModel)
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Tracking is not performed in the background. Re-check
            // authorization, elapsed time and GPS quality on return.
            if newPhase == .active {
                trackingViewModel.handleForegroundEntry()
            }
        }
    }
}
