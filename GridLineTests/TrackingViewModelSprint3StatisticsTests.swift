//
//  TrackingViewModelSprint3StatisticsTests.swift
//  GridLineTests
//
//  Created by Kenton & Ethan.
//

import CoreLocation
import Foundation
import Testing
@testable import GridLine

@Suite("Sprint 3 - FR-10 Session Statistics Integration")
@MainActor
struct TrackingViewModelSprint3StatisticsTests {

    @Test("TC-39 final statistics freeze after Stop and reset for a new session")
    func statisticsFreezeAfterStopAndResetOnRestart() async {

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
                speed: 12,
                timestamp: clock.current
            )
        )

        await settleSprint2Callbacks()

        clock.advance(by: 1)

        viewModel.stopTracking()

        let finalStatistics =
            viewModel.sessionStatistics

        #expect(finalStatistics.elapsedSeconds == 3)
        #expect(finalStatistics.acceptedSampleCount == 2)
        #expect(finalStatistics.rejectedSampleCount == 0)
        #expect(finalStatistics.maximumSpeedMetersPerSecond == 12)

        #expect(
            (11.0...11.2).contains(
                finalStatistics.totalDistanceMeters
            )
        )

        // Time passing and late readings must not change a completed session.
        clock.advance(by: 60)

        viewModel.refreshClock()

        service.emitLocation(
            makeTestLocation(
                latitude: 40.8000 + 2 * sprint3LatitudeStep,
                course: 0,
                speed: 30,
                timestamp: clock.current
            )
        )

        await settleSprint2Callbacks()

        #expect(viewModel.sessionStatistics == finalStatistics)

        viewModel.startTracking()

        #expect(viewModel.isTracking)
        #expect(viewModel.sessionStatistics == .zero)
        #expect(viewModel.sessionStatistics.maximumSpeedMetersPerSecond == nil)
        #expect(viewModel.sessionMetrics == .zero)
        #expect(viewModel.samples.isEmpty)
        #expect(viewModel.acceptedSamples.isEmpty)
        #expect(viewModel.rejectionCounts.isEmpty)

        clock.advance(by: 1)

        service.emitLocation(
            makeTestLocation(
                latitude: 40.9000,
                course: 0,
                speed: 3,
                timestamp: clock.current
            )
        )

        await settleSprint2Callbacks()

        // The new maximum comes only from the new session.
        #expect(viewModel.sessionStatistics.maximumSpeedMetersPerSecond == 3)
        #expect(viewModel.sessionStatistics.acceptedSampleCount == 1)
        #expect(viewModel.sessionStatistics.elapsedSeconds == 1)
        #expect(viewModel.sessionStatistics.totalDistanceMeters == 0)
    }

    @Test("TC-50 counts and averages use only trusted readings over total elapsed time")
    func statisticsUseTrustedCountsAndTotalElapsedTime() async {

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

        // Rejected for poor accuracy. Its high speed must not become the maximum.
        clock.advance(by: 1)

        service.emitLocation(
            makeTestLocation(
                latitude: 40.8000 + sprint3LatitudeStep,
                horizontalAccuracy: 100,
                course: 0,
                speed: 60,
                timestamp: clock.current
            )
        )

        await settleSprint2Callbacks()

        // First recovery candidate. It is held, not accepted or rejected.
        clock.advance(by: 1)

        service.emitLocation(
            makeTestLocation(
                latitude: 40.8000 + 2 * sprint3LatitudeStep,
                course: 0,
                speed: 50,
                timestamp: clock.current
            )
        )

        await settleSprint2Callbacks()

        let statistics =
            viewModel.sessionStatistics

        #expect(viewModel.samples.count == 4)
        #expect(viewModel.acceptedSamples.count == 2)
        #expect(viewModel.rejectedSampleCount == 1)
        #expect(viewModel.rejectionCounts[.poorAccuracy] == 1)

        let pendingCount =
            viewModel.samples.count -
            viewModel.acceptedSamples.count -
            viewModel.rejectedSampleCount

        #expect(pendingCount == 1)

        #expect(
            statistics.acceptedSampleCount ==
                viewModel.acceptedSamples.count
        )

        #expect(
            statistics.rejectedSampleCount ==
                viewModel.rejectedSampleCount
        )

        #expect(statistics.maximumSpeedMetersPerSecond == 10)

        // No new GPS, but the session keeps running for a total of 100 seconds.
        clock.advance(by: 96)

        viewModel.refreshClock()

        let refreshed =
            viewModel.sessionStatistics

        #expect(refreshed.elapsedSeconds == 100)

        #expect(
            (11.0...11.2).contains(
                refreshed.totalDistanceMeters
            )
        )

        // About 11.1 m / 100 s. A mean of the sample speeds would be 10 m/s.
        #expect(
            (0.110...0.112).contains(
                refreshed.averageSpeedMetersPerSecond
            )
        )

        #expect(
            abs(
                refreshed.averageSpeedMetersPerSecond -
                    refreshed.totalDistanceMeters / 100
            ) < 0.000_001
        )

        #expect(refreshed.maximumSpeedMetersPerSecond == 10)
        #expect(refreshed.acceptedSampleCount == 2)
        #expect(refreshed.rejectedSampleCount == 1)
    }
}
