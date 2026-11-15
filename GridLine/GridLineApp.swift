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

    @StateObject private var trackingViewModel = GridlineApp.makeTrackingViewModel()

    @Environment(\.scenePhase) private var scenePhase

    private static func makeTrackingViewModel() -> TrackingViewModel {
        #if DEBUG
        // UI system tests launch with a scripted location scenario so they
        // never depend on live GPS or the permission sheet.
        if let service = UITestLocationService.fromProcessEnvironment() {
            return TrackingViewModel(locationService: service)
        }
        #endif

        return TrackingViewModel()
    }

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
