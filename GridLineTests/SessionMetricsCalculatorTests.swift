//
//  SessionMetricsCalculatorTests.swift
//  GridLineTests
//
//  Created by Kenton & Ethan.
//

import Foundation
import Testing
@testable import GridLine

@Suite("Sprint 2 - FR-09 Time and Distance")
struct SessionMetricsCalculatorTests {

    @Test("TC-32 elapsed time runs during the session and freezes after Stop")
    func elapsedTimeFreezesAfterStop() {

        let start =
            Date(timeIntervalSince1970: 2_000_000_000)

        var calculator = SessionMetricsCalculator()

        calculator.start(at: start)

        #expect(calculator.isRunning)

        #expect(
            calculator.elapsedSeconds(
                at: start.addingTimeInterval(25)
            ) == 25
        )

        calculator.stop(
            at: start.addingTimeInterval(30)
        )

        #expect(calculator.isRunning == false)

        #expect(
            calculator.elapsedSeconds(
                at: start.addingTimeInterval(100)
            ) == 30
        )

        // A second Stop should not change the final time.
        calculator.stop(
            at: start.addingTimeInterval(40)
        )

        #expect(
            calculator.elapsedSeconds(
                at: start.addingTimeInterval(100)
            ) == 30
        )
    }

    @Test("TC-33 continuous accepted movement adds distance")
    func continuousMovementAddsDistance() throws {

        let start =
            Date(timeIntervalSince1970: 2_000_000_000)

        var calculator = SessionMetricsCalculator()
        calculator.start(at: start)

        let first = makeTestSample(
            latitude: 40.8000,
            longitude: -77.8600,
            timestamp: start.addingTimeInterval(1)
        )

        let second = makeTestSample(
            latitude: 40.8001,
            longitude: -77.8600,
            timestamp: start.addingTimeInterval(11)
        )

        calculator.record(
            makeAcceptedResult(
                sample: first,
                kind: .initialAnchor
            )
        )

        calculator.record(
            makeAcceptedResult(
                sample: second,
                kind: .continuous,
                previous: first
            )
        )

        let expectedDistance =
            first.distance(to: second)

        #expect(calculator.totalDistanceMeters > 0)

        #expect(
            abs(
                calculator.totalDistanceMeters -
                    expectedDistance
            ) < 0.01
        )
    }

    @Test("TC-34 small GPS jitter is ignored until movement exceeds the deadband")
    func jitterIsIgnoredUntilMovementBecomesMeaningful() {

        let start =
            Date(timeIntervalSince1970: 2_000_000_000)

        var calculator = SessionMetricsCalculator()
        calculator.start(at: start)

        let initial = makeTestSample(
            latitude: 40.8000,
            longitude: -77.8600,
            horizontalAccuracy: 1,
            timestamp: start.addingTimeInterval(1)
        )

        calculator.record(
            makeAcceptedResult(
                sample: initial,
                kind: .initialAnchor
            )
        )

        let tinyMoveOne = makeTestSample(
            latitude: 40.8000,
            longitude: -77.85999,
            horizontalAccuracy: 1,
            timestamp: start.addingTimeInterval(2)
        )

        calculator.record(
            makeAcceptedResult(
                sample: tinyMoveOne,
                kind: .continuous,
                previous: initial
            )
        )

        #expect(
            calculator.totalDistanceMeters == 0
        )

        let tinyMoveTwo = makeTestSample(
            latitude: 40.8000,
            longitude: -77.85998,
            horizontalAccuracy: 1,
            timestamp: start.addingTimeInterval(3)
        )

        calculator.record(
            makeAcceptedResult(
                sample: tinyMoveTwo,
                kind: .continuous,
                previous: tinyMoveOne
            )
        )

        #expect(
            calculator.totalDistanceMeters == 0
        )

        let meaningfulMove = makeTestSample(
            latitude: 40.8000,
            longitude: -77.85996,
            horizontalAccuracy: 1,
            timestamp: start.addingTimeInterval(5)
        )

        calculator.record(
            makeAcceptedResult(
                sample: meaningfulMove,
                kind: .continuous,
                previous: tinyMoveTwo
            )
        )

        #expect(
            calculator.totalDistanceMeters > 0
        )
    }

    @Test("TC-35 distance is not calculated across a GPS interruption")
    func interruptionDoesNotAddGapDistance() {

        let start =
            Date(timeIntervalSince1970: 2_000_000_000)

        var calculator = SessionMetricsCalculator()
        calculator.start(at: start)

        let first = makeTestSample(
            latitude: 40.8000,
            longitude: -77.8600,
            timestamp: start.addingTimeInterval(1)
        )

        let second = makeTestSample(
            latitude: 40.8001,
            longitude: -77.8600,
            timestamp: start.addingTimeInterval(2)
        )

        calculator.record(
            makeAcceptedResult(
                sample: first,
                kind: .initialAnchor
            )
        )

        calculator.record(
            makeAcceptedResult(
                sample: second,
                kind: .continuous,
                previous: first
            )
        )

        let distanceBeforeGap =
            calculator.totalDistanceMeters

        calculator.breakContinuity()

        // Simulate reacquiring GPS much farther away.
        let recovery = makeTestSample(
            latitude: 41.8000,
            longitude: -77.8600,
            timestamp: start.addingTimeInterval(20)
        )

        calculator.record(
            makeAcceptedResult(
                sample: recovery,
                kind: .recoveryAnchor
            )
        )

        // The large gap must not count toward distance.
        #expect(
            calculator.totalDistanceMeters ==
                distanceBeforeGap
        )

        let afterRecovery = makeTestSample(
            latitude: 41.8001,
            longitude: -77.8600,
            timestamp: start.addingTimeInterval(21)
        )

        calculator.record(
            makeAcceptedResult(
                sample: afterRecovery,
                kind: .continuous,
                previous: recovery
            )
        )

        #expect(
            calculator.totalDistanceMeters >
                distanceBeforeGap
        )

        // Confirms the huge GPS gap was not added.
        #expect(
            calculator.totalDistanceMeters < 100
        )
    }

    @Test("TC-36 readings received after Stop do not add distance")
    func postStopReadingsDoNotChangeDistance() {

        let start =
            Date(timeIntervalSince1970: 2_000_000_000)

        var calculator = SessionMetricsCalculator()
        calculator.start(at: start)

        let first = makeTestSample(
            latitude: 40.8000,
            longitude: -77.8600,
            timestamp: start.addingTimeInterval(1)
        )

        calculator.record(
            makeAcceptedResult(
                sample: first,
                kind: .initialAnchor
            )
        )

        calculator.stop(
            at: start.addingTimeInterval(10)
        )

        let afterStop = makeTestSample(
            latitude: 40.8100,
            longitude: -77.8600,
            timestamp: start.addingTimeInterval(11)
        )

        calculator.record(
            makeAcceptedResult(
                sample: afterStop,
                kind: .continuous,
                previous: first
            )
        )

        #expect(
            calculator.totalDistanceMeters == 0
        )
    }
}
