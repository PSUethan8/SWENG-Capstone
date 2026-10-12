//
//  MovementMetricsProcessorTests.swift
//  GridLineTests
//
//  Created by Kenton & Ethan.
//

import Foundation
import Testing
@testable import GridLine

@Suite("Sprint 2 - FR-08 Speed and Direction")
struct MovementMetricsProcessorTests {

    @Test("TC-27 uses valid sensor speed and direction")
    func usesSensorMovementWhenAvailable() throws {

        let sample = makeTestSample(
            course: 90,
            speed: 10
        )

        let result = makeAcceptedResult(
            sample: sample,
            kind: .initialAnchor
        )

        var processor = MovementMetricsProcessor()

        let metrics = processor.update(with: result)

        #expect(metrics.speedMetersPerSecond == 10)
        #expect(metrics.speedSource == .sensor)

        #expect(metrics.courseDegrees == 90)
        #expect(metrics.courseSource == .sensor)

        let mph = try #require(metrics.speedMPH)

        #expect(
            abs(mph - 22.3694) < 0.0001
        )

        #expect(metrics.compassDirection == "E")
    }

    @Test("TC-28 derives speed and direction when sensor values are unavailable")
    func derivesMovementFromTrustedLocations() throws {

        let start =
            Date(timeIntervalSince1970: 2_000_000_000)

        let previous = makeTestSample(
            latitude: 40.8000,
            longitude: -77.8600,
            timestamp: start
        )

        let current = makeTestSample(
            latitude: 40.8000,
            longitude: -77.8590,
            timestamp: start.addingTimeInterval(10)
        )

        let result = makeAcceptedResult(
            sample: current,
            kind: .continuous,
            previous: previous
        )

        var processor = MovementMetricsProcessor()

        let metrics = processor.update(with: result)

        #expect(metrics.speedSource == .derived)
        #expect(metrics.courseSource == .derived)

        let speed =
            try #require(metrics.speedMetersPerSecond)

        let course =
            try #require(metrics.courseDegrees)

        #expect(speed > 0)

        // Movement is almost directly east.
        #expect(abs(course - 90) < 1)
        #expect(metrics.compassDirection == "E")
    }

    @Test("TC-29 stationary speed does not display a direction")
    func stationaryReadingDoesNotShowDirection() {

        let sample = makeTestSample(
            course: 180,
            speed: 0
        )

        let result = makeAcceptedResult(
            sample: sample,
            kind: .initialAnchor
        )

        var processor = MovementMetricsProcessor()

        let metrics = processor.update(with: result)

        #expect(metrics.speedMetersPerSecond == 0)
        #expect(metrics.speedSource == .sensor)

        #expect(metrics.courseDegrees == nil)
        #expect(metrics.courseSource == nil)
        #expect(metrics.compassDirection == nil)
    }

    @Test("TC-30 rejected GPS readings do not change movement metrics")
    func rejectedReadingLeavesMovementUnchanged() {

        let validSample = makeTestSample(
            course: 90,
            speed: 10
        )

        let validResult = makeAcceptedResult(
            sample: validSample,
            kind: .initialAnchor
        )

        var processor = MovementMetricsProcessor()

        let original =
            processor.update(with: validResult)

        let rejectedSample = makeTestSample(
            latitude: 41,
            longitude: -78
        )

        let rejectedResult = makeRejectedResult(
            sample: rejectedSample,
            reason: .implausibleMovement
        )

        let afterRejected =
            processor.update(with: rejectedResult)

        #expect(afterRejected == original)
        #expect(processor.current == original)
    }

    @Test("TC-31 movement is not derived across a recovery gap")
    func recoveryAnchorDoesNotDeriveMovementAcrossGap() {

        var processor = MovementMetricsProcessor()

        let original = makeTestSample(
            course: 90,
            speed: 10
        )

        _ = processor.update(
            with: makeAcceptedResult(
                sample: original,
                kind: .initialAnchor
            )
        )

        let recoveredLocation = makeTestSample(
            latitude: 41.0000,
            longitude: -78.0000
        )

        let recoveryResult = makeAcceptedResult(
            sample: recoveredLocation,
            kind: .recoveryAnchor
        )

        let metrics =
            processor.update(with: recoveryResult)

        #expect(metrics == .unavailable)
        #expect(processor.current == .unavailable)
    }
}
