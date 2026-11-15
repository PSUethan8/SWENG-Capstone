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

    // Sprint 4 - one history model (and one archive store) for the whole app,
    // shared by the tracking flow and the history screens.
    @StateObject private var sessionHistory: SessionHistoryModel

    @StateObject private var trackingViewModel: TrackingViewModel

    @Environment(\.scenePhase) private var scenePhase

    init() {
        let history = SessionHistoryModel(
            store: GridlineApp.makeSessionStore()
        )

        _sessionHistory = StateObject(
            wrappedValue: history
        )

        _trackingViewModel = StateObject(
            wrappedValue: GridlineApp.makeTrackingViewModel(
                sessionHistory: history
            )
        )
    }

    private static func makeSessionStore() -> any SessionStoring {
        #if DEBUG
        // Scripted UI-test drives use an isolated store so they never
        // reach real history on the device.
        if UITestLocationService.fromProcessEnvironment() != nil {
            return InMemorySessionStore()
        }
        #endif

        return FileSessionStore.applicationSupport()
    }

    private static func makeTrackingViewModel(
        sessionHistory: SessionHistoryModel
    ) -> TrackingViewModel {
        #if DEBUG
        // UI system tests launch with a scripted location scenario so they
        // never depend on live GPS or the permission sheet.
        if let service = UITestLocationService.fromProcessEnvironment() {
            return TrackingViewModel(
                locationService: service,
                sessionHistory: sessionHistory
            )
        }
        #endif

        return TrackingViewModel(
            sessionHistory: sessionHistory
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(trackingViewModel)
                .environmentObject(sessionHistory)
                .task {
                    // Load saved drives at launch. Reviewing history never
                    // requires location permission.
                    await sessionHistory.loadIfNeeded()
                }
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
