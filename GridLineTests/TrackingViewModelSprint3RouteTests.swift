//
//  TrackingViewModelSprint3RouteTests.swift
//  GridLineTests
//
//  Created by Kenton & Ethan.
//

import CoreLocation
import Foundation
import Testing
@testable import GridLine

/// Ways GPS continuity can be broken during a session.
enum Sprint3RouteInterruption: String, CaseIterable {
    case timeout
    case poorAccuracy
    case permissionLoss
}

@Suite("Sprint 3 - FR-13 Recorded Route")
@MainActor
struct TrackingViewModelSprint3RouteTests {

    @Test("RouteSegment keeps its identifier and sample order when extended")
    func routeSegmentKeepsIdentifierWhenExtended() {

        let start =
            Date(timeIntervalSince1970: 2_000_000_000)

        let first = makeTestSample(
            latitude: 40.8000,
            timestamp: start
        )

        let second = makeTestSample(
            latitude: 40.8001,
            timestamp: start.addingTimeInterval(1)
        )

        let third = makeTestSample(
            latitude: 40.8002,
            timestamp: start.addingTimeInterval(2)
        )

        var segment = RouteSegment(anchor: first)
        let id = segment.id

        segment.append(second)
        segment.append(third)

        #expect(segment.id == id)
        #expect(segment.samples.map(\.id) == [first.id, second.id, third.id])

        #expect(
            segment.coordinates.map(\.latitude) ==
                [40.8000, 40.8001, 40.8002]
        )

        #expect(
            segment.coordinates.map(\.longitude) ==
                [-77.8600, -77.8600, -77.8600]
        )
    }

    @Test("TC-46 continuous accepted readings extend one route segment")
    func continuousReadingsExtendOneSegment() async throws {

        let service = Sprint2MockLocationService()
        let clock = TestClock()

        let viewModel = TrackingViewModel(
            locationService: service,
            now: { clock.current }
        )

        defer { viewModel.stopTracking() }

        viewModel.startTracking()

        #expect(viewModel.routeSegments.isEmpty)

        clock.advance(by: 1)

        service.emitLocation(
            makeTestLocation(
                latitude: 40.8000,
                timestamp: clock.current
            )
        )

        await settleSprint2Callbacks()

        let segmentID =
            try #require(viewModel.routeSegments.first?.id)

        #expect(viewModel.routeSegments.count == 1)

        for step in 1...2 {

            clock.advance(by: 1)

            service.emitLocation(
                makeTestLocation(
                    latitude: 40.8000 + Double(step) * sprint3LatitudeStep,
                    timestamp: clock.current
                )
            )

            await settleSprint2Callbacks()
        }

        let segment =
            try #require(viewModel.routeSegments.first)

        #expect(viewModel.routeSegments.count == 1)
        #expect(segment.id == segmentID)

        // Samples are stored in arrival order and match the accepted readings.
        #expect(
            segment.samples.map(\.id) ==
                viewModel.acceptedSamples.map(\.id)
        )

        #expect(segment.samples.count == 3)

        #expect(
            segment.coordinates.map(\.latitude) ==
                viewModel.acceptedSamples.map(\.latitude)
        )

        #expect(
            segment.coordinates.map(\.longitude) ==
                viewModel.acceptedSamples.map(\.longitude)
        )
    }

    @Test(
        "TC-47 a GPS interruption starts a separate route segment",
        arguments: Sprint3RouteInterruption.allCases
    )
    func interruptionStartsSeparateSegment(
        _ interruption: Sprint3RouteInterruption
    ) async throws {

        let service = Sprint2MockLocationService()
        let clock = TestClock()

        let viewModel = TrackingViewModel(
            locationService: service,
            now: { clock.current }
        )

        defer { viewModel.stopTracking() }

        viewModel.startTracking()

        for step in 0..<2 {

            clock.advance(by: 1)

            service.emitLocation(
                makeTestLocation(
                    latitude: 40.8000 + Double(step) * sprint3LatitudeStep,
                    course: 0,
                    speed: 10,
                    timestamp: clock.current
                )
            )

            await settleSprint2Callbacks()
        }

        let firstSegment =
            try #require(viewModel.routeSegments.first)

        let distanceBeforeInterruption =
            viewModel.sessionMetrics.totalDistanceMeters

        switch interruption {

        case .timeout:

            clock.advance(by: 11)

            viewModel.refreshClock()

            #expect(viewModel.gpsQuality == .temporarilyUnavailable)

        case .poorAccuracy:

            clock.advance(by: 1)

            service.emitLocation(
                makeTestLocation(
                    latitude: 40.8000 + 2 * sprint3LatitudeStep,
                    horizontalAccuracy: 100,
                    timestamp: clock.current
                )
            )

            await settleSprint2Callbacks()

            #expect(viewModel.gpsQuality == .poorAccuracy)

        case .permissionLoss:

            service.emitAuthorization(.denied)
            await settleSprint2Callbacks()

            #expect(viewModel.gpsQuality == .permissionUnavailable)

            service.emitAuthorization(.authorizedWhenInUse)
            await settleSprint2Callbacks()

            #expect(viewModel.gpsQuality == .acquiring)
        }

        #expect(viewModel.routeSegments == [firstSegment])

        // Recover about 1.1 km away. Joining the outage would add that gap.
        let recoveryLatitude = 40.8100

        clock.advance(by: 1)

        service.emitLocation(
            makeTestLocation(
                latitude: recoveryLatitude,
                course: 0,
                speed: 10,
                timestamp: clock.current
            )
        )

        await settleSprint2Callbacks()

        let pendingSample =
            try #require(viewModel.samples.last)

        // A pending recovery candidate adds no route point.
        #expect(viewModel.routeSegments == [firstSegment])

        #expect(
            routeSampleIDs(viewModel.routeSegments)
                .contains(pendingSample.id) == false
        )

        clock.advance(by: 1)

        service.emitLocation(
            makeTestLocation(
                latitude: recoveryLatitude + sprint3LatitudeStep,
                course: 0,
                speed: 10,
                timestamp: clock.current
            )
        )

        await settleSprint2Callbacks()

        #expect(viewModel.gpsQuality == .good)
        #expect(viewModel.routeSegments.count == 2)

        let recoverySegment =
            try #require(viewModel.routeSegments.last)

        #expect(recoverySegment.id != firstSegment.id)
        #expect(recoverySegment.samples.count == 1)

        clock.advance(by: 1)

        service.emitLocation(
            makeTestLocation(
                latitude: recoveryLatitude + 2 * sprint3LatitudeStep,
                course: 0,
                speed: 10,
                timestamp: clock.current
            )
        )

        await settleSprint2Callbacks()

        // Continuous movement extends the recovery segment only.
        #expect(viewModel.routeSegments.count == 2)
        #expect(viewModel.routeSegments.first == firstSegment)
        #expect(viewModel.routeSegments.last?.id == recoverySegment.id)
        #expect(viewModel.routeSegments.last?.samples.count == 2)

        #expect(
            routeSampleIDs(viewModel.routeSegments) ==
                viewModel.acceptedSamples.map(\.id)
        )

        // Only the two 11 meter segments count, never the 1.1 km gap.
        let totalDistance =
            viewModel.sessionMetrics.totalDistanceMeters

        #expect(totalDistance < 50)
        #expect((11.0...11.2).contains(distanceBeforeInterruption))
        #expect((22.0...22.4).contains(totalDistance))
    }

    @Test("TC-48 rejected and pending readings never enter the route")
    func rejectedReadingsNeverEnterRoute() async throws {

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

        func emit(
            latitude: Double,
            horizontalAccuracy: Double = 5,
            timestamp: Date? = nil
        ) async {

            service.emitLocation(
                makeTestLocation(
                    latitude: latitude,
                    horizontalAccuracy: horizontalAccuracy,
                    timestamp: timestamp ?? clock.current
                )
            )

            await settleSprint2Callbacks()
        }

        // A, then B five seconds later.
        clock.advance(by: 1)
        await emit(latitude: 40.8000)

        clock.advance(by: 5)
        await emit(latitude: 40.8000 + sprint3LatitudeStep)

        clock.advance(by: 5)

        // Stale: 10.5 seconds old but still after the session started.
        await emit(
            latitude: 40.8000 + sprint3LatitudeStep,
            timestamp: startTime.addingTimeInterval(0.5)
        )

        // Out of order: older than the last evaluated reading.
        await emit(
            latitude: 40.8000 + sprint3LatitudeStep,
            timestamp: startTime.addingTimeInterval(5)
        )

        // Invalid coordinate.
        await emit(latitude: 91)

        // Isolated implausible jump of about 22 km.
        await emit(latitude: 41.0000)

        // C continues from B.
        clock.advance(by: 1)
        await emit(latitude: 40.8000 + 2 * sprint3LatitudeStep)

        // Poor accuracy breaks continuity.
        clock.advance(by: 1)
        await emit(latitude: 40.8000 + 3 * sprint3LatitudeStep, horizontalAccuracy: 100)

        // Pending recovery candidate.
        clock.advance(by: 1)
        await emit(latitude: 40.8000 + 3 * sprint3LatitudeStep)

        let pendingSample =
            try #require(viewModel.samples.last)

        // Recovery anchor, then D continues from it.
        clock.advance(by: 1)
        await emit(latitude: 40.8000 + 4 * sprint3LatitudeStep)

        clock.advance(by: 1)
        await emit(latitude: 40.8000 + 5 * sprint3LatitudeStep)

        let routeIDs =
            routeSampleIDs(viewModel.routeSegments)

        let acceptedIDs =
            viewModel.acceptedSamples.map(\.id)

        #expect(viewModel.samples.count == 11)
        #expect(acceptedIDs.count == 5)
        #expect(viewModel.rejectedSampleCount == 5)

        for reason: LocationRejectionReason in [
            .staleTimestamp,
            .outOfOrderTimestamp,
            .invalidCoordinate,
            .implausibleMovement,
            .poorAccuracy
        ] {
            #expect(viewModel.rejectionCounts[reason] == 1)
        }

        // Flattened route equals accepted readings in order, including the
        // recovery anchor, and excludes the pending candidate.
        #expect(routeIDs == acceptedIDs)
        #expect(routeIDs.contains(pendingSample.id) == false)

        let unusedIDs =
            Set(viewModel.samples.map(\.id))
                .subtracting(acceptedIDs)

        #expect(unusedIDs.count == 6)
        #expect(unusedIDs.isDisjoint(with: routeIDs))

        // Two segments: [A, B, C] and [anchor, D].
        #expect(viewModel.routeSegments.map(\.samples.count) == [3, 2])

        #expect(
            viewModel.routeSegments.first?.coordinates.map(\.latitude) ==
                [
                    40.8000,
                    40.8000 + sprint3LatitudeStep,
                    40.8000 + 2 * sprint3LatitudeStep
                ]
        )
    }

    @Test("TC-56 the completed route freezes and a new session starts a new route")
    func completedRouteFreezesAndNewSessionStartsNewRoute() async throws {

        let service = Sprint2MockLocationService()
        let clock = TestClock()

        let viewModel = TrackingViewModel(
            locationService: service,
            now: { clock.current }
        )

        defer { viewModel.stopTracking() }

        viewModel.startTracking()

        for step in 0..<3 {

            clock.advance(by: 1)

            service.emitLocation(
                makeTestLocation(
                    latitude: 40.8000 + Double(step) * sprint3LatitudeStep,
                    timestamp: clock.current
                )
            )

            await settleSprint2Callbacks()
        }

        clock.advance(by: 1)

        // Queued before Stop, delivered after Stop.
        service.emitQueuedLocation(
            makeTestLocation(
                latitude: 40.8000 + 3 * sprint3LatitudeStep,
                timestamp: clock.current
            )
        )

        viewModel.stopTracking()

        let completedRoute =
            viewModel.routeSegments

        let completedSegmentIDs =
            completedRoute.map(\.id)

        let completedSampleIDs =
            routeSampleIDs(completedRoute)

        #expect(completedRoute.count == 1)
        #expect(completedSampleIDs.count == 3)

        await settleSprint2Callbacks()

        // Ordinary late delivery after Stop.
        clock.advance(by: 1)

        service.emitLocation(
            makeTestLocation(
                latitude: 40.8000 + 4 * sprint3LatitudeStep,
                timestamp: clock.current
            )
        )

        await settleSprint2Callbacks()

        #expect(viewModel.routeSegments == completedRoute)

        // A new session clears every old segment.
        clock.advance(by: 10)

        viewModel.startTracking()

        #expect(viewModel.routeSegments.isEmpty)

        let newLatitudes = [40.9000, 40.9000 + sprint3LatitudeStep]

        for latitude in newLatitudes {

            clock.advance(by: 1)

            service.emitLocation(
                makeTestLocation(
                    latitude: latitude,
                    timestamp: clock.current
                )
            )

            await settleSprint2Callbacks()
        }

        let newSegment =
            try #require(viewModel.routeSegments.first)

        #expect(viewModel.routeSegments.count == 1)
        #expect(completedSegmentIDs.contains(newSegment.id) == false)
        #expect(newSegment.coordinates.map(\.latitude) == newLatitudes)

        #expect(
            routeSampleIDs(viewModel.routeSegments)
                .allSatisfy { completedSampleIDs.contains($0) == false }
        )
    }
}
