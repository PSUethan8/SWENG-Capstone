//
//  TrackingViewModelSprint3SummaryTests.swift
//  GridLineTests
//
//  Created by Kenton & Ethan.
//

import CoreLocation
import Foundation
import Testing
@testable import GridLine

@Suite("Sprint 3 - FR-12 Completed Session Summary")
@MainActor
struct TrackingViewModelSprint3SummaryTests {

    @Test("TC-43 the completed summary matches the final session statistics")
    func completedSummaryMatchesFinalStatistics() async throws {

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

        #expect(viewModel.hasCompletedSession == false)

        let speeds = [10.0, 20.0, 15.0]

        for (index, speed) in speeds.enumerated() {

            clock.advance(by: 1)

            service.emitLocation(
                makeTestLocation(
                    latitude: 40.8000 + Double(index) * sprint3LatitudeStep,
                    course: 0,
                    speed: speed,
                    timestamp: clock.current
                )
            )

            await settleSprint2Callbacks()

            // One out-of-order reading is filtered after the second fix.
            if index == 1 {

                service.emitLocation(
                    makeTestLocation(
                        latitude: 40.8000,
                        timestamp: clock.current.addingTimeInterval(-0.5)
                    )
                )

                await settleSprint2Callbacks()
            }
        }

        clock.advance(by: 17)

        viewModel.stopTracking()

        #expect(viewModel.hasCompletedSession)
        #expect(viewModel.sessionEndTime == startTime.addingTimeInterval(20))

        let summary =
            viewModel.sessionStatistics

        // Fixed expectations for this route.
        #expect(summary.elapsedSeconds == 20)
        #expect((22.0...22.4).contains(summary.totalDistanceMeters))
        #expect((1.10...1.12).contains(summary.averageSpeedMetersPerSecond))
        #expect(summary.maximumSpeedMetersPerSecond == 20)
        #expect(summary.acceptedSampleCount == 3)
        #expect(summary.rejectedSampleCount == 1)

        let maximumMPH =
            try #require(summary.maximumSpeedMPH)

        #expect(
            abs(
                maximumMPH -
                    44.7388
            ) < 0.000_1
        )

        // The summary agrees with the other final session values.
        #expect(
            summary.elapsedSeconds ==
                viewModel.sessionMetrics.elapsedSeconds
        )

        #expect(
            summary.totalDistanceMeters ==
                viewModel.sessionMetrics.totalDistanceMeters
        )

        #expect(
            summary.acceptedSampleCount ==
                viewModel.acceptedSamples.count
        )

        #expect(
            summary.rejectedSampleCount ==
                viewModel.rejectedSampleCount
        )
    }

    @Test("TC-44 the completed summary and route stay frozen after Stop")
    func completedSummaryStaysFrozen() async throws {

        let service = Sprint2MockLocationService()
        let clock = TestClock()

        let viewModel = TrackingViewModel(
            locationService: service,
            now: { clock.current }
        )

        defer { viewModel.stopTracking() }

        viewModel.startTracking()

        for index in 0..<2 {

            clock.advance(by: 1)

            service.emitLocation(
                makeTestLocation(
                    latitude: 40.8000 + Double(index) * sprint3LatitudeStep,
                    course: 0,
                    speed: 10,
                    timestamp: clock.current
                )
            )

            await settleSprint2Callbacks()
        }

        clock.advance(by: 1)

        // Queue a reading from the active session, then Stop before it is
        // delivered. The queued reading belongs to an older generation.
        service.emitQueuedLocation(
            makeTestLocation(
                latitude: 40.8000 + 2 * sprint3LatitudeStep,
                course: 0,
                speed: 30,
                timestamp: clock.current
            )
        )

        viewModel.stopTracking()

        let statistics = viewModel.sessionStatistics
        let metrics = viewModel.sessionMetrics
        let route = viewModel.routeSegments
        let endTime = try #require(viewModel.sessionEndTime)
        let sampleIDs = viewModel.samples.map(\.id)
        let acceptedIDs = viewModel.acceptedSamples.map(\.id)
        let rejectionCounts = viewModel.rejectionCounts

        #expect(statistics.acceptedSampleCount == 2)
        #expect(route.count == 1)

        await settleSprint2Callbacks()

        // Time passing and returning to the app.
        clock.advance(by: 30)

        viewModel.refreshClock()
        viewModel.handleForegroundEntry()

        // Ordinary late callbacks after Stop.
        service.emitLocation(
            makeTestLocation(
                latitude: 40.8000 + 3 * sprint3LatitudeStep,
                course: 0,
                speed: 40,
                timestamp: clock.current
            )
        )

        service.emitError(Sprint2MockError())
        service.emitError(CLError(.locationUnknown))

        // Queued late callbacks after Stop.
        service.emitQueuedLocation(
            makeTestLocation(
                latitude: 40.8000 + 4 * sprint3LatitudeStep,
                course: 0,
                speed: 40,
                timestamp: clock.current
            )
        )

        service.emitQueuedError(Sprint2MockError())

        await settleSprint2Callbacks()

        #expect(viewModel.isTracking == false)
        #expect(viewModel.hasCompletedSession)
        #expect(viewModel.sessionEndTime == endTime)
        #expect(viewModel.currentTime == endTime)

        #expect(viewModel.sessionStatistics == statistics)
        #expect(viewModel.sessionMetrics == metrics)
        #expect(viewModel.routeSegments == route)
        #expect(viewModel.samples.map(\.id) == sampleIDs)
        #expect(viewModel.acceptedSamples.map(\.id) == acceptedIDs)
        #expect(viewModel.rejectionCounts == rejectionCounts)

        #expect(viewModel.movement == .unavailable)
        #expect(viewModel.gpsQuality == .inactive)
        #expect(viewModel.errorMessage == nil)

        // Nothing restarted location updates.
        #expect(service.startUpdatingLocationCallCount == 1)
    }

    @Test("TC-45 a new session clears the previous summary and route")
    func newSessionClearsPreviousSummary() async throws {

        let service = Sprint2MockLocationService()
        let clock = TestClock()

        let viewModel = TrackingViewModel(
            locationService: service,
            now: { clock.current }
        )

        defer { viewModel.stopTracking() }

        viewModel.startTracking()

        for index in 0..<2 {

            clock.advance(by: 1)

            service.emitLocation(
                makeTestLocation(
                    latitude: 40.8000 + Double(index) * sprint3LatitudeStep,
                    course: 0,
                    speed: 20,
                    timestamp: clock.current
                )
            )

            await settleSprint2Callbacks()
        }

        clock.advance(by: 1)

        service.emitLocation(
            makeTestLocation(
                horizontalAccuracy: 100,
                timestamp: clock.current
            )
        )

        await settleSprint2Callbacks()

        clock.advance(by: 1)

        viewModel.stopTracking()

        #expect(viewModel.hasCompletedSession)
        #expect(viewModel.sessionStatistics.maximumSpeedMetersPerSecond == 20)
        #expect(viewModel.sessionStatistics.rejectedSampleCount == 1)

        let previousSegmentIDs =
            viewModel.routeSegments.map(\.id)

        let previousSampleIDs =
            routeSampleIDs(viewModel.routeSegments)

        #expect(previousSegmentIDs.count == 1)

        // Review the summary, then start another session.
        clock.advance(by: 30)

        viewModel.startTracking()

        // A reading queued during one session must not leak into the next
        // session when Stop and Start happen before it is delivered.
        service.emitQueuedLocation(
            makeTestLocation(
                latitude: 40.8000 + 5 * sprint3LatitudeStep,
                course: 0,
                speed: 25,
                timestamp: clock.current
            )
        )

        viewModel.stopTracking()
        viewModel.startTracking()

        await settleSprint2Callbacks()

        #expect(viewModel.isTracking)
        #expect(viewModel.hasCompletedSession == false)
        #expect(viewModel.sessionEndTime == nil)

        #expect(viewModel.sessionStatistics == .zero)
        #expect(viewModel.sessionStatistics.maximumSpeedMetersPerSecond == nil)
        #expect(viewModel.sessionMetrics == .zero)
        #expect(viewModel.routeSegments.isEmpty)
        #expect(viewModel.samples.isEmpty)
        #expect(viewModel.acceptedSamples.isEmpty)
        #expect(viewModel.rejectionCounts.isEmpty)

        clock.advance(by: 1)

        let newLocation =
            makeTestLocation(
                latitude: 40.9000,
                course: 0,
                speed: 5,
                timestamp: clock.current
            )

        service.emitLocation(newLocation)

        await settleSprint2Callbacks()

        #expect(viewModel.sessionStatistics.maximumSpeedMetersPerSecond == 5)
        #expect(viewModel.sessionStatistics.acceptedSampleCount == 1)
        #expect(viewModel.sessionStatistics.rejectedSampleCount == 0)

        let segment =
            try #require(viewModel.routeSegments.first)

        #expect(viewModel.routeSegments.count == 1)
        #expect(previousSegmentIDs.contains(segment.id) == false)

        #expect(
            routeSampleIDs(viewModel.routeSegments)
                .allSatisfy { previousSampleIDs.contains($0) == false }
        )

        #expect(segment.coordinates.count == 1)
        #expect(segment.coordinates.first?.latitude == 40.9000)
    }

    @Test("TC-53 Stop without a GPS fix produces a valid empty summary")
    func stopWithoutFixProducesEmptySummary() throws {

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

        clock.advance(by: 5)

        viewModel.stopTracking()

        let summary =
            viewModel.sessionStatistics

        #expect(viewModel.hasCompletedSession)
        #expect(viewModel.sessionEndTime == startTime.addingTimeInterval(5))

        #expect(summary.elapsedSeconds == 5)
        #expect(summary.totalDistanceMeters == 0)
        #expect(summary.averageSpeedMetersPerSecond == 0)
        #expect(summary.maximumSpeedMetersPerSecond == nil)
        #expect(summary.maximumSpeedMPH == nil)
        #expect(summary.acceptedSampleCount == 0)
        #expect(summary.rejectedSampleCount == 0)
        #expect(viewModel.routeSegments.isEmpty)

        // A repeated Stop does not change the end time or values.
        clock.advance(by: 10)

        viewModel.stopTracking()

        #expect(viewModel.sessionEndTime == startTime.addingTimeInterval(5))
        #expect(viewModel.sessionStatistics == summary)

        // An immediate Start/Stop has zero duration and no division by zero.
        viewModel.startTracking()
        viewModel.stopTracking()

        let immediate =
            viewModel.sessionStatistics

        #expect(viewModel.hasCompletedSession)
        #expect(viewModel.sessionEndTime == viewModel.sessionStartTime)

        #expect(immediate.elapsedSeconds == 0)
        #expect(immediate.totalDistanceMeters == 0)
        #expect(immediate.averageSpeedMetersPerSecond == 0)
        #expect(immediate.averageSpeedMetersPerSecond.isFinite)
        #expect(immediate.averageSpeedMPH.isFinite)
        #expect(immediate.maximumSpeedMetersPerSecond == nil)
        #expect(immediate.acceptedSampleCount == 0)
        #expect(immediate.rejectedSampleCount == 0)
    }
}
