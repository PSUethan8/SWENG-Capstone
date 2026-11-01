//
//  SessionStatisticsCalculatorTests.swift
//  GridLineTests
//
//  Created by Kenton & Ethan.
//

import Foundation
import Testing
@testable import GridLine

@Suite("Sprint 3 - FR-10 Session Statistics")
struct SessionStatisticsCalculatorTests {

    @Test("TC-37 builds statistics and converts them to display units")
    func buildsStatisticsAndConvertsUnits() {

        let calculator = SessionStatisticsCalculator()

        let statistics =
            calculator.statistics(
                sessionMetrics:
                    SessionMetrics(
                        elapsedSeconds: 100,
                        totalDistanceMeters: 1_000
                    ),
                acceptedSampleCount: 12,
                rejectedSampleCount: 3
            )

        #expect(statistics.elapsedSeconds == 100)
        #expect(statistics.totalDistanceMeters == 1_000)

        // 1,000 m / 100 s, not a mean of individual sample speeds.
        #expect(
            abs(
                statistics.averageSpeedMetersPerSecond -
                    10
            ) < 0.000_001
        )

        // 1,000 m / 1,609.344 m per mile.
        #expect(
            abs(
                statistics.totalDistanceMiles -
                    0.621_371
            ) < 0.000_001
        )

        // 10 m/s * 2.23694.
        #expect(
            abs(
                statistics.averageSpeedMPH -
                    22.3694
            ) < 0.000_1
        )

        #expect(statistics.acceptedSampleCount == 12)
        #expect(statistics.rejectedSampleCount == 3)

        #expect(statistics.maximumSpeedMetersPerSecond == nil)
        #expect(statistics.maximumSpeedMPH == nil)
    }

    @Test("TC-38 maximum speed ignores unavailable and invalid values")
    func maximumSpeedIgnoresInvalidValues() throws {

        var calculator = SessionStatisticsCalculator()

        for speed in [5.0, 12.0, 8.0] {
            calculator.record(
                MovementMetrics(
                    speedMetersPerSecond: speed
                )
            )
        }

        #expect(calculator.maximumSpeedMetersPerSecond == 12)

        let invalidSpeeds: [Double?] = [
            nil,
            -1,
            .nan,
            .infinity,
            -.infinity
        ]

        for speed in invalidSpeeds {
            calculator.record(
                MovementMetrics(
                    speedMetersPerSecond: speed
                )
            )
        }

        #expect(calculator.maximumSpeedMetersPerSecond == 12)

        let statistics =
            calculator.statistics(
                sessionMetrics: .zero,
                acceptedSampleCount: 0,
                rejectedSampleCount: 0
            )

        let maximumMPH =
            try #require(statistics.maximumSpeedMPH)

        #expect(
            abs(
                maximumMPH -
                    26.843_28
            ) < 0.000_1
        )

        // A valid stationary speed is a real maximum, not an unknown value.
        var stationaryCalculator = SessionStatisticsCalculator()

        stationaryCalculator.record(
            MovementMetrics(
                speedMetersPerSecond: nil
            )
        )

        #expect(stationaryCalculator.maximumSpeedMetersPerSecond == nil)

        stationaryCalculator.record(
            MovementMetrics(
                speedMetersPerSecond: 0
            )
        )

        #expect(stationaryCalculator.maximumSpeedMetersPerSecond == 0)

        stationaryCalculator.record(
            MovementMetrics(
                speedMetersPerSecond: -1
            )
        )

        #expect(stationaryCalculator.maximumSpeedMetersPerSecond == 0)

        stationaryCalculator.reset()

        #expect(stationaryCalculator.maximumSpeedMetersPerSecond == nil)
    }

    @Test("TC-49 empty, zero-duration, and negative inputs stay finite")
    func boundaryInputsProduceFiniteStatistics() {

        let calculator = SessionStatisticsCalculator()

        let empty =
            calculator.statistics(
                sessionMetrics: .zero,
                acceptedSampleCount: 0,
                rejectedSampleCount: 0
            )

        #expect(empty == .zero)
        #expect(empty.maximumSpeedMetersPerSecond == nil)

        // Distance with no elapsed time must not divide by zero.
        let zeroDuration =
            calculator.statistics(
                sessionMetrics:
                    SessionMetrics(
                        elapsedSeconds: 0,
                        totalDistanceMeters: 250
                    ),
                acceptedSampleCount: 2,
                rejectedSampleCount: 0
            )

        #expect(zeroDuration.elapsedSeconds == 0)
        #expect(zeroDuration.totalDistanceMeters == 250)
        #expect(zeroDuration.averageSpeedMetersPerSecond == 0)

        let negativeTime =
            calculator.statistics(
                sessionMetrics:
                    SessionMetrics(
                        elapsedSeconds: -30,
                        totalDistanceMeters: 100
                    ),
                acceptedSampleCount: 0,
                rejectedSampleCount: 0
            )

        #expect(negativeTime.elapsedSeconds == 0)
        #expect(negativeTime.averageSpeedMetersPerSecond == 0)

        let negativeDistance =
            calculator.statistics(
                sessionMetrics:
                    SessionMetrics(
                        elapsedSeconds: 60,
                        totalDistanceMeters: -100
                    ),
                acceptedSampleCount: 0,
                rejectedSampleCount: 0
            )

        #expect(negativeDistance.elapsedSeconds == 60)
        #expect(negativeDistance.totalDistanceMeters == 0)
        #expect(negativeDistance.averageSpeedMetersPerSecond == 0)

        for statistics in [
            empty,
            zeroDuration,
            negativeTime,
            negativeDistance
        ] {
            #expect(statistics.elapsedSeconds.isFinite)
            #expect(statistics.totalDistanceMeters.isFinite)
            #expect(statistics.averageSpeedMetersPerSecond.isFinite)
            #expect(statistics.totalDistanceMiles.isFinite)
            #expect(statistics.averageSpeedMPH.isFinite)
        }
    }
}
