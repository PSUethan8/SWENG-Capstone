//
//  TrackingViewModelSprint3LiveTests.swift
//  GridLineTests
//
//  Created by Kenton & Ethan.
//

import CoreLocation
import Foundation
import Testing
@testable import GridLine

@Suite("Sprint 3 - FR-11 Current Tracking Information")
@MainActor
struct TrackingViewModelSprint3LiveTests {

    @Test("TC-40 live values match trusted moving GPS readings")
    func liveValuesMatchMovingReadings() async throws {

        let service = Sprint2MockLocationService()
        let clock = TestClock()

        let viewModel = TrackingViewModel(
            locationService: service,
            now: { clock.current }
        )

        defer { viewModel.stopTracking() }

        viewModel.startTracking()

        // Moving east about 12.6 meters per second.
        let longitudeStep = 0.00015
        let accuracies = [5.0, 5.0, 8.0]

        for (index, accuracy) in accuracies.enumerated() {

            clock.advance(by: 1)

            service.emitLocation(
                makeTestLocation(
                    latitude: 40.8000,
                    longitude: -77.8600 + Double(index) * longitudeStep,
                    horizontalAccuracy: accuracy,
                    course: 90,
                    speed: 10,
                    timestamp: clock.current
                )
            )

            await settleSprint2Callbacks()
        }

        #expect(viewModel.gpsQuality == .good)

        #expect(viewModel.movement.speedMetersPerSecond == 10)
        #expect(viewModel.movement.speedSource == .sensor)

        let speedMPH =
            try #require(viewModel.currentSpeedMPH)

        #expect(
            abs(
                speedMPH -
                    22.3694
            ) < 0.000_1
        )

        #expect(viewModel.movement.courseDegrees == 90)
        #expect(viewModel.movement.compassDirection == "E")

        #expect(viewModel.sessionMetrics.elapsedSeconds == 3)

        #expect(
            (25.0...25.6).contains(
                viewModel.sessionMetrics.totalDistanceMeters
            )
        )

        // Latest accuracy comes from the newest reading.
        #expect(viewModel.currentAccuracyMeters == 8)

        #expect(viewModel.acceptedSamples.count == 3)
        #expect(viewModel.samples.count == 3)

        #expect(
            viewModel.latestAcceptedSample?.id ==
                viewModel.samples.last?.id
        )
    }

    @Test("TC-41 GPS interruptions clear movement but keep the session")
    func interruptionsClearMovementButKeepSession() async throws {

        let service = Sprint2MockLocationService()
        let clock = TestClock()

        let viewModel = TrackingViewModel(
            locationService: service,
            now: { clock.current }
        )

        defer { viewModel.stopTracking() }

        viewModel.startTracking()

        let startTime =
            try #require(viewModel.sessionStartTime)

        var step = 0.0

        func emitTrustedReading() async {

            clock.advance(by: 1)

            service.emitLocation(
                makeTestLocation(
                    latitude: 40.8000 + step * sprint3LatitudeStep,
                    course: 0,
                    speed: 10,
                    timestamp: clock.current
                )
            )

            step += 1

            await settleSprint2Callbacks()
        }

        await emitTrustedReading()
        await emitTrustedReading()

        #expect(viewModel.gpsQuality == .good)
        #expect(viewModel.movement.speedMetersPerSecond == 10)

        let trustedSample =
            try #require(viewModel.latestAcceptedSample)

        // An out-of-order reading is rejected without breaking continuity.
        service.emitLocation(
            makeTestLocation(
                latitude: 40.8000,
                timestamp: clock.current.addingTimeInterval(-0.5)
            )
        )

        await settleSprint2Callbacks()

        #expect(viewModel.rejectionCounts[.outOfOrderTimestamp] == 1)
        #expect(viewModel.gpsQuality == .good)
        #expect(viewModel.movement.speedMetersPerSecond == 10)
        #expect(viewModel.latestAcceptedSample?.id == trustedSample.id)

        // An isolated implausible jump is also rejected without clearing movement.
        clock.advance(by: 1)

        service.emitLocation(
            makeTestLocation(
                latitude: 41.0000,
                course: 0,
                speed: 10,
                timestamp: clock.current
            )
        )

        await settleSprint2Callbacks()

        #expect(viewModel.rejectionCounts[.implausibleMovement] == 1)
        #expect(viewModel.gpsQuality == .good)
        #expect(viewModel.movement.speedMetersPerSecond == 10)
        #expect(viewModel.latestAcceptedSample?.id == trustedSample.id)

        // The next normal reading continues from the trusted location.
        await emitTrustedReading()

        #expect(viewModel.acceptedSamples.count == 3)
        #expect(viewModel.gpsQuality == .good)

        let distanceBeforeInterruptions =
            viewModel.sessionMetrics.totalDistanceMeters

        #expect(
            (22.0...22.4).contains(
                distanceBeforeInterruptions
            )
        )

        // Poor accuracy breaks continuity.
        clock.advance(by: 1)

        service.emitLocation(
            makeTestLocation(
                latitude: 40.8000 + step * sprint3LatitudeStep,
                horizontalAccuracy: 100,
                course: 0,
                speed: 10,
                timestamp: clock.current
            )
        )

        await settleSprint2Callbacks()

        #expect(viewModel.isTracking)
        #expect(viewModel.gpsQuality == .poorAccuracy)
        #expect(viewModel.movement == .unavailable)
        #expect(viewModel.sessionStartTime == startTime)

        #expect(
            viewModel.sessionMetrics.totalDistanceMeters ==
                distanceBeforeInterruptions
        )

        // One recovery candidate is not enough to trust the location yet.
        await emitTrustedReading()

        #expect(viewModel.gpsQuality == .poorAccuracy)
        #expect(viewModel.movement == .unavailable)

        await emitTrustedReading()

        #expect(viewModel.gpsQuality == .good)
        #expect(viewModel.movement.speedMetersPerSecond == 10)

        // A timeout breaks continuity without a Core Location callback.
        clock.advance(by: 11)

        viewModel.refreshClock()

        #expect(viewModel.isTracking)
        #expect(viewModel.gpsQuality == .temporarilyUnavailable)
        #expect(viewModel.movement == .unavailable)
        #expect(viewModel.sessionStartTime == startTime)

        #expect(
            viewModel.sessionMetrics.totalDistanceMeters ==
                distanceBeforeInterruptions
        )

        await emitTrustedReading()
        await emitTrustedReading()

        #expect(viewModel.gpsQuality == .good)
        #expect(viewModel.movement.speedMetersPerSecond == 10)

        // Losing permission suspends acquisition but keeps the session.
        service.emitAuthorization(.denied)
        await settleSprint2Callbacks()

        #expect(viewModel.isTracking)
        #expect(viewModel.gpsQuality == .permissionUnavailable)
        #expect(viewModel.movement == .unavailable)
        #expect(viewModel.sessionStartTime == startTime)

        service.emitAuthorization(.authorizedWhenInUse)
        await settleSprint2Callbacks()

        #expect(viewModel.gpsQuality == .acquiring)

        await emitTrustedReading()
        await emitTrustedReading()

        #expect(viewModel.isTracking)
        #expect(viewModel.gpsQuality == .good)
        #expect(viewModel.movement.speedMetersPerSecond == 10)
        #expect(viewModel.sessionStartTime == startTime)

        // Every recovery started a new anchor, so no gap distance was added.
        #expect(
            viewModel.sessionMetrics.totalDistanceMeters ==
                distanceBeforeInterruptions
        )
    }

    @Test("TC-42 stationary zero speed is valid and different from unavailable")
    func stationarySpeedDiffersFromUnavailable() async throws {

        let service = Sprint2MockLocationService()
        let clock = TestClock()

        let viewModel = TrackingViewModel(
            locationService: service,
            now: { clock.current }
        )

        defer { viewModel.stopTracking() }

        viewModel.startTracking()

        // Before any GPS reading, speed and direction are unknown.
        #expect(viewModel.currentSpeedMPH == nil)
        #expect(viewModel.movement.courseDegrees == nil)

        clock.advance(by: 1)

        service.emitLocation(
            makeTestLocation(
                course: -1,
                speed: 0,
                timestamp: clock.current
            )
        )

        await settleSprint2Callbacks()

        #expect(viewModel.currentSpeedMPH == 0)
        #expect(viewModel.movement.speedSource == .sensor)

        // Stationary readings never show a direction.
        #expect(viewModel.movement.courseDegrees == nil)
        #expect(viewModel.movement.compassDirection == nil)

        clock.advance(by: 1)

        service.emitLocation(
            makeTestLocation(
                course: 45,
                speed: 0,
                timestamp: clock.current
            )
        )

        await settleSprint2Callbacks()

        #expect(viewModel.currentSpeedMPH == 0)
        #expect(viewModel.movement.courseDegrees == nil)

        // A timeout makes movement unavailable rather than zero.
        clock.advance(by: 11)

        viewModel.refreshClock()

        #expect(viewModel.currentSpeedMPH == nil)
        #expect(viewModel.movement.courseDegrees == nil)
        #expect(viewModel.movement.compassDirection == nil)

        // A recovery anchor without sensor speed cannot derive speed
        // across the gap, so speed stays unavailable.
        clock.advance(by: 1)

        service.emitLocation(
            makeTestLocation(
                latitude: 40.8000 + sprint3LatitudeStep,
                timestamp: clock.current
            )
        )

        await settleSprint2Callbacks()

        clock.advance(by: 1)

        service.emitLocation(
            makeTestLocation(
                latitude: 40.8000 + 2 * sprint3LatitudeStep,
                timestamp: clock.current
            )
        )

        await settleSprint2Callbacks()

        #expect(viewModel.gpsQuality == .good)
        #expect(viewModel.currentSpeedMPH == nil)
        #expect(viewModel.movement.courseDegrees == nil)
    }

    @Test("TC-51 the clock refreshes time and average without new GPS")
    func clockRefreshUpdatesTimeWithoutGPS() async throws {

        let service = Sprint2MockLocationService()
        let clock = TestClock()

        let viewModel = TrackingViewModel(
            locationService: service,
            now: { clock.current }
        )

        defer { viewModel.stopTracking() }

        viewModel.startTracking()

        let startTime =
            try #require(viewModel.sessionStartTime)

        clock.advance(by: 1)

        service.emitLocation(
            makeTestLocation(
                latitude: 40.8000,
                course: 0,
                speed: 10,
                timestamp: clock.current
            )
        )

        await settleSprint2Callbacks()

        clock.advance(by: 1)

        service.emitLocation(
            makeTestLocation(
                latitude: 40.8000 + sprint3LatitudeStep,
                course: 0,
                speed: 10,
                timestamp: clock.current
            )
        )

        await settleSprint2Callbacks()

        let distance =
            viewModel.sessionMetrics.totalDistanceMeters

        let routeIDs =
            routeSampleIDs(viewModel.routeSegments)

        #expect((11.0...11.2).contains(distance))
        #expect(routeIDs.count == 2)

        // Four seconds without GPS, below the timeout.
        clock.advance(by: 4)

        viewModel.refreshClock()

        #expect(viewModel.sessionMetrics.elapsedSeconds == 6)
        #expect(viewModel.sessionStatistics.elapsedSeconds == 6)

        #expect(
            (1.83...1.87).contains(
                viewModel.sessionStatistics.averageSpeedMetersPerSecond
            )
        )

        #expect(viewModel.sessionMetrics.totalDistanceMeters == distance)
        #expect(routeSampleIDs(viewModel.routeSegments) == routeIDs)
        #expect(viewModel.gpsQuality == .good)
        #expect(viewModel.movement.speedMetersPerSecond == 10)

        // Exactly at the 10 second timeout is not yet a timeout.
        clock.advance(by: 6)

        viewModel.refreshClock()

        #expect(viewModel.sessionMetrics.elapsedSeconds == 12)
        #expect(viewModel.gpsQuality == .good)
        #expect(viewModel.movement.speedMetersPerSecond == 10)

        // Beyond the timeout, live movement clears but the session continues.
        clock.advance(by: 1)

        viewModel.refreshClock()

        #expect(viewModel.isTracking)
        #expect(viewModel.sessionStartTime == startTime)
        #expect(viewModel.sessionMetrics.elapsedSeconds == 13)
        #expect(viewModel.gpsQuality == .temporarilyUnavailable)
        #expect(viewModel.movement == .unavailable)

        #expect(
            (0.84...0.87).contains(
                viewModel.sessionStatistics.averageSpeedMetersPerSecond
            )
        )

        #expect(viewModel.sessionMetrics.totalDistanceMeters == distance)
        #expect(routeSampleIDs(viewModel.routeSegments) == routeIDs)
        #expect(viewModel.samples.count == 2)
    }

    @Test("TC-52 support - latest accuracy can show a rejected reading")
    func latestAccuracyReflectsRejectedReading() async throws {

        let service = Sprint2MockLocationService()
        let clock = TestClock()

        let viewModel = TrackingViewModel(
            locationService: service,
            now: { clock.current }
        )

        defer { viewModel.stopTracking() }

        viewModel.startTracking()

        clock.advance(by: 1)

        service.emitLocation(
            makeTestLocation(
                latitude: 40.8000,
                course: 0,
                speed: 10,
                timestamp: clock.current
            )
        )

        await settleSprint2Callbacks()

        clock.advance(by: 1)

        service.emitLocation(
            makeTestLocation(
                latitude: 40.8000 + sprint3LatitudeStep,
                course: 0,
                speed: 10,
                timestamp: clock.current
            )
        )

        await settleSprint2Callbacks()

        let trustedSample =
            try #require(viewModel.latestAcceptedSample)

        let distance =
            viewModel.sessionMetrics.totalDistanceMeters

        let routeIDs =
            routeSampleIDs(viewModel.routeSegments)

        clock.advance(by: 1)

        service.emitLocation(
            makeTestLocation(
                latitude: 40.8100,
                horizontalAccuracy: 80,
                course: 0,
                speed: 10,
                timestamp: clock.current
            )
        )

        await settleSprint2Callbacks()

        // Accuracy shows the raw reading, even though it was rejected.
        #expect(viewModel.currentAccuracyMeters == 80)
        #expect(viewModel.rejectionCounts[.poorAccuracy] == 1)

        // Trusted coordinates, distance, route, and movement are not replaced.
        #expect(viewModel.latestAcceptedSample?.id == trustedSample.id)
        #expect(viewModel.sessionMetrics.totalDistanceMeters == distance)
        #expect(routeSampleIDs(viewModel.routeSegments) == routeIDs)
        #expect(viewModel.movement == .unavailable)
        #expect(viewModel.gpsQuality == .poorAccuracy)

        // An invalid accuracy value is not shown at all.
        clock.advance(by: 1)

        service.emitLocation(
            makeTestLocation(
                horizontalAccuracy: -1,
                timestamp: clock.current
            )
        )

        await settleSprint2Callbacks()

        #expect(viewModel.currentAccuracyMeters == nil)
    }
}
