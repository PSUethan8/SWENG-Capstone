//
//  LocationProcessorTests.swift
//  GridLineTests
//
//  Created by Kenton & Ethan.
//

import Foundation
import Testing
@testable import GridLine

@Suite("Sprint 2 - FR-06 GPS Filtering")
struct LocationProcessorTests {

    @Test("TC-16 accepts the first trustworthy GPS reading")
    func acceptsInitialTrustedReading() {

        let start =
            Date(timeIntervalSince1970: 2_000_000_000)

        var processor = LocationProcessor()
        processor.reset(sessionStartTime: start)

        let sample = makeTestSample(
            timestamp: start.addingTimeInterval(1)
        )

        let result = processor.process(
            sample: sample,
            receivedAt: start.addingTimeInterval(1)
        )

        #expect(result.isAccepted)
        #expect(result.acceptanceKind == .initialAnchor)
        #expect(result.previousAcceptedSample == nil)
        #expect(processor.hasContinuousSegment)
    }

    @Test("TC-17 rejects invalid and poor-quality GPS readings")
    func rejectsInvalidAndPoorQualityReadings() {

        let start =
            Date(timeIntervalSince1970: 2_000_000_000)

        var processor = LocationProcessor()
        processor.reset(sessionStartTime: start)

        let invalidCoordinate = makeTestSample(
            latitude: 100,
            timestamp: start.addingTimeInterval(1)
        )

        let coordinateResult = processor.process(
            sample: invalidCoordinate,
            receivedAt: start.addingTimeInterval(1)
        )

        #expect(
            coordinateResult.rejectionReason ==
                .invalidCoordinate
        )

        let invalidAccuracy = makeTestSample(
            horizontalAccuracy: -1,
            timestamp: start.addingTimeInterval(2)
        )

        let accuracyResult = processor.process(
            sample: invalidAccuracy,
            receivedAt: start.addingTimeInterval(2)
        )

        #expect(
            accuracyResult.rejectionReason ==
                .invalidAccuracy
        )

        let poorAccuracy = makeTestSample(
            horizontalAccuracy: 100,
            timestamp: start.addingTimeInterval(3)
        )

        let poorResult = processor.process(
            sample: poorAccuracy,
            receivedAt: start.addingTimeInterval(3)
        )

        #expect(
            poorResult.rejectionReason ==
                .poorAccuracy
        )

        #expect(poorResult.breaksContinuity)
    }

    @Test("TC-18 rejects readings with invalid timestamps")
    func rejectsInvalidTimestamps() {

        let start =
            Date(timeIntervalSince1970: 2_000_000_000)

        var processor = LocationProcessor()
        processor.reset(sessionStartTime: start)

        let beforeSession = makeTestSample(
            timestamp: start.addingTimeInterval(-1)
        )

        let beforeResult = processor.process(
            sample: beforeSession,
            receivedAt: start.addingTimeInterval(1)
        )

        #expect(
            beforeResult.rejectionReason ==
                .beforeSessionStart
        )

        let stale = makeTestSample(
            timestamp: start.addingTimeInterval(1)
        )

        let staleResult = processor.process(
            sample: stale,
            receivedAt: start.addingTimeInterval(20)
        )

        #expect(
            staleResult.rejectionReason ==
                .staleTimestamp
        )

        let future = makeTestSample(
            timestamp: start.addingTimeInterval(10)
        )

        let futureResult = processor.process(
            sample: future,
            receivedAt: start.addingTimeInterval(1)
        )

        #expect(
            futureResult.rejectionReason ==
                .futureTimestamp
        )
    }

    @Test("TC-19 rejects an older reading after a newer reading was evaluated")
    func rejectsOutOfOrderReading() {

        let start =
            Date(timeIntervalSince1970: 2_000_000_000)

        var processor = LocationProcessor()
        processor.reset(sessionStartTime: start)

        let first = makeTestSample(
            timestamp: start.addingTimeInterval(1)
        )

        _ = processor.process(
            sample: first,
            receivedAt: start.addingTimeInterval(1)
        )

        let newerPoorReading = makeTestSample(
            horizontalAccuracy: 100,
            timestamp: start.addingTimeInterval(5)
        )

        _ = processor.process(
            sample: newerPoorReading,
            receivedAt: start.addingTimeInterval(5)
        )

        let olderReading = makeTestSample(
            timestamp: start.addingTimeInterval(4)
        )

        let result = processor.process(
            sample: olderReading,
            receivedAt: start.addingTimeInterval(5)
        )

        #expect(
            result.rejectionReason ==
                .outOfOrderTimestamp
        )
    }

    @Test("TC-20 rejects an isolated implausible GPS jump")
    func rejectsImplausibleJumpWithoutReplacingTrustedLocation() {

        let start =
            Date(timeIntervalSince1970: 2_000_000_000)

        var processor = LocationProcessor()
        processor.reset(sessionStartTime: start)

        let first = makeTestSample(
            latitude: 40.8000,
            longitude: -77.8600,
            timestamp: start.addingTimeInterval(1)
        )

        _ = processor.process(
            sample: first,
            receivedAt: start.addingTimeInterval(1)
        )

        let jump = makeTestSample(
            latitude: 41.8000,
            longitude: -77.8600,
            timestamp: start.addingTimeInterval(2)
        )

        let jumpResult = processor.process(
            sample: jump,
            receivedAt: start.addingTimeInterval(2)
        )

        #expect(
            jumpResult.rejectionReason ==
                .implausibleMovement
        )

        let normalReading = makeTestSample(
            latitude: 40.8001,
            longitude: -77.8600,
            timestamp: start.addingTimeInterval(3)
        )

        let normalResult = processor.process(
            sample: normalReading,
            receivedAt: start.addingTimeInterval(3)
        )

        #expect(normalResult.isAccepted)
        #expect(
            normalResult.acceptanceKind ==
                .continuous
        )

        #expect(
            normalResult.previousAcceptedSample?.latitude ==
                first.latitude
        )
    }

    @Test("TC-21 confirms a new trusted location after GPS recovery")
    func confirmsRecoveryAfterContinuityBreak() {

        let start =
            Date(timeIntervalSince1970: 2_000_000_000)

        var processor = LocationProcessor()
        processor.reset(sessionStartTime: start)

        let first = makeTestSample(
            timestamp: start.addingTimeInterval(1)
        )

        _ = processor.process(
            sample: first,
            receivedAt: start.addingTimeInterval(1)
        )

        let poor = makeTestSample(
            horizontalAccuracy: 100,
            timestamp: start.addingTimeInterval(2)
        )

        _ = processor.process(
            sample: poor,
            receivedAt: start.addingTimeInterval(2)
        )

        let recoveryOne = makeTestSample(
            latitude: 40.8001,
            timestamp: start.addingTimeInterval(3)
        )

        let firstRecoveryResult = processor.process(
            sample: recoveryOne,
            receivedAt: start.addingTimeInterval(3)
        )

        #expect(
            firstRecoveryResult.disposition ==
                .pendingRecovery
        )

        let recoveryTwo = makeTestSample(
            latitude: 40.8002,
            timestamp: start.addingTimeInterval(4)
        )

        let secondRecoveryResult = processor.process(
            sample: recoveryTwo,
            receivedAt: start.addingTimeInterval(4)
        )

        #expect(secondRecoveryResult.isAccepted)

        #expect(
            secondRecoveryResult.acceptanceKind ==
                .recoveryAnchor
        )

        #expect(processor.hasContinuousSegment)
    }
}
