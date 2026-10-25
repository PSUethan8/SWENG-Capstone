//
//  SessionStatisticsCalculator.swift
//  GridLine
//
//  Created by Kenton & Ethan.
//

import Foundation

/// Builds session-level statistics from already validated movement and
/// session metrics. Only processed movement values are recorded here.
struct SessionStatisticsCalculator {

    private(set) var maximumSpeedMetersPerSecond: Double?

    mutating func reset() {
        maximumSpeedMetersPerSecond = nil
    }

    mutating func record(_ movement: MovementMetrics) {

        guard let speed = movement.speedMetersPerSecond,
              speed.isFinite,
              speed >= 0 else {
            return
        }

        maximumSpeedMetersPerSecond = max(
            maximumSpeedMetersPerSecond ?? speed,
            speed
        )
    }

    func statistics(
        sessionMetrics: SessionMetrics,
        acceptedSampleCount: Int,
        rejectedSampleCount: Int
    ) -> SessionStatistics {

        let elapsed = max(
            0,
            sessionMetrics.elapsedSeconds
        )

        let distance = max(
            0,
            sessionMetrics.totalDistanceMeters
        )

        let averageSpeed =
            elapsed > 0
            ? distance / elapsed
            : 0

        return SessionStatistics(
            elapsedSeconds: elapsed,
            totalDistanceMeters: distance,
            averageSpeedMetersPerSecond: averageSpeed,
            maximumSpeedMetersPerSecond: maximumSpeedMetersPerSecond,
            acceptedSampleCount: acceptedSampleCount,
            rejectedSampleCount: rejectedSampleCount
        )
    }
}
