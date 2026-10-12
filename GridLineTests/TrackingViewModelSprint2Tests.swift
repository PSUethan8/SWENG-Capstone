//
//  TrackingViewModelSprint2Tests.swift
//  GridLineTests
//
//  Created by Kenton & Ethan.
//

import CoreLocation
import Foundation
import Testing
@testable import GridLine

@Suite("Sprint 2 - FR-07 GPS Interruptions")
@MainActor
struct TrackingViewModelSprint2Tests {

    @Test("TC-22 poor GPS accuracy keeps the session active")
    func poorAccuracyDoesNotEndSession() async {

        let service = Sprint2MockLocationService()
        let clock = TestClock()

        let viewModel = TrackingViewModel(
            locationService: service,
            now: { clock.current }
        )

        viewModel.startTracking()

        clock.advance(by: 1)

        service.emitLocation(
            makeTestLocation(
                horizontalAccuracy: 5,
                course: 90,
                speed: 10,
                timestamp: clock.current
            )
        )

        await settleSprint2Callbacks()

        #expect(viewModel.gpsQuality == .good)
        #expect(viewModel.acceptedSamples.count == 1)

        clock.advance(by: 1)

        service.emitLocation(
            makeTestLocation(
                horizontalAccuracy: 100,
                timestamp: clock.current
            )
        )

        await settleSprint2Callbacks()

        #expect(viewModel.isTracking)

        #expect(
            viewModel.gpsQuality ==
                .poorAccuracy
        )

        #expect(viewModel.samples.count == 2)
        #expect(viewModel.acceptedSamples.count == 1)

        #expect(
            viewModel.rejectionCounts[.poorAccuracy] ==
                1
        )

        #expect(viewModel.movement == .unavailable)
    }

    @Test("TC-23 GPS timeout keeps the session running")
    func timeoutMarksGPSUnavailableWithoutEndingSession() async {

        let service = Sprint2MockLocationService()
        let clock = TestClock()

        let viewModel = TrackingViewModel(
            locationService: service,
            now: { clock.current }
        )

        viewModel.startTracking()

        clock.advance(by: 1)

        service.emitLocation(
            makeTestLocation(
                course: 90,
                speed: 10,
                timestamp: clock.current
            )
        )

        await settleSprint2Callbacks()

        #expect(viewModel.gpsQuality == .good)

        clock.advance(by: 11)

        viewModel.refreshClock()

        #expect(viewModel.isTracking)

        #expect(
            viewModel.gpsQuality ==
                .temporarilyUnavailable
        )

        #expect(viewModel.movement == .unavailable)

        #expect(
            viewModel.secondsSinceLastAcceptedFix == 11
        )
    }

    @Test("TC-24 losing location permission suspends and later resumes GPS")
    func permissionLossAndRestoreKeepsSessionAlive() async {

        let service = Sprint2MockLocationService()
        let clock = TestClock()

        let viewModel = TrackingViewModel(
            locationService: service,
            now: { clock.current }
        )

        viewModel.startTracking()

        #expect(
            service.startUpdatingLocationCallCount ==
                1
        )

        service.emitAuthorization(.denied)
        await settleSprint2Callbacks()

        #expect(viewModel.isTracking)

        #expect(
            viewModel.gpsQuality ==
                .permissionUnavailable
        )

        #expect(
            service.stopUpdatingLocationCallCount ==
                1
        )

        #expect(viewModel.errorMessage != nil)

        service.emitAuthorization(.authorizedWhenInUse)
        await settleSprint2Callbacks()

        #expect(viewModel.isTracking)
        #expect(viewModel.gpsQuality == .acquiring)

        #expect(
            service.startUpdatingLocationCallCount ==
                2
        )

        #expect(viewModel.errorMessage == nil)
    }

    @Test("TC-25 reliable readings restore GPS after poor accuracy")
    func goodReadingsRestoreGPSAfterInterruption() async {

        let service = Sprint2MockLocationService()
        let clock = TestClock()

        let viewModel = TrackingViewModel(
            locationService: service,
            now: { clock.current }
        )

        viewModel.startTracking()

        clock.advance(by: 1)

        service.emitLocation(
            makeTestLocation(
                latitude: 40.8000,
                timestamp: clock.current
            )
        )

        await settleSprint2Callbacks()

        clock.advance(by: 1)

        service.emitLocation(
            makeTestLocation(
                latitude: 40.8000,
                horizontalAccuracy: 100,
                timestamp: clock.current
            )
        )

        await settleSprint2Callbacks()

        #expect(viewModel.gpsQuality == .poorAccuracy)

        clock.advance(by: 1)

        service.emitLocation(
            makeTestLocation(
                latitude: 40.8001,
                timestamp: clock.current
            )
        )

        await settleSprint2Callbacks()

        #expect(viewModel.acceptedSamples.count == 1)
        #expect(viewModel.gpsQuality == .poorAccuracy)

        clock.advance(by: 1)

        service.emitLocation(
            makeTestLocation(
                latitude: 40.8002,
                timestamp: clock.current
            )
        )

        await settleSprint2Callbacks()

        #expect(viewModel.acceptedSamples.count == 2)
        #expect(viewModel.gpsQuality == .good)

        // No distance should be added across the GPS gap.
        #expect(
            viewModel.sessionMetrics.totalDistanceMeters ==
                0
        )
    }

    @Test("TC-26 transient errors clear after reliable GPS returns")
    func transientErrorClearsAfterRecovery() async {

        let service = Sprint2MockLocationService()
        let clock = TestClock()

        let viewModel = TrackingViewModel(
            locationService: service,
            now: { clock.current }
        )

        viewModel.startTracking()

        clock.advance(by: 1)

        service.emitLocation(
            makeTestLocation(
                latitude: 40.8000,
                timestamp: clock.current
            )
        )

        await settleSprint2Callbacks()

        service.emitError(Sprint2MockError())
        await settleSprint2Callbacks()

        #expect(viewModel.isTracking)

        #expect(
            viewModel.gpsQuality ==
                .temporarilyUnavailable
        )

        #expect(
            viewModel.errorMessage ==
                "Simulated Sprint 2 location failure"
        )

        clock.advance(by: 1)

        service.emitLocation(
            makeTestLocation(
                latitude: 40.8001,
                timestamp: clock.current
            )
        )

        await settleSprint2Callbacks()

        clock.advance(by: 1)

        service.emitLocation(
            makeTestLocation(
                latitude: 40.8002,
                timestamp: clock.current
            )
        )

        await settleSprint2Callbacks()

        #expect(viewModel.gpsQuality == .good)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isTracking)
    }
}
