//
//  SessionStatistics.swift
//  GridLine
//
//  Created by Kenton & Ethan
//

import Foundation

/// Summary values calculated from trusted session data.
struct SessionStatistics: Equatable {

    static let zero = SessionStatistics(
        elapsedSeconds: 0,
        totalDistanceMeters: 0,
        averageSpeedMetersPerSecond: 0,
        maximumSpeedMetersPerSecond: nil,
        acceptedSampleCount: 0,
        rejectedSampleCount: 0
    )

    let elapsedSeconds: TimeInterval
    let totalDistanceMeters: Double
    let averageSpeedMetersPerSecond: Double
    let maximumSpeedMetersPerSecond: Double?
    let acceptedSampleCount: Int
    let rejectedSampleCount: Int

    var totalDistanceMiles: Double {
        totalDistanceMeters / SessionMetrics.metersPerMile
    }

    var averageSpeedMPH: Double {
        averageSpeedMetersPerSecond * MovementMetrics.metersPerSecondToMPH
    }

    var maximumSpeedMPH: Double? {
        maximumSpeedMetersPerSecond.map {
            $0 * MovementMetrics.metersPerSecondToMPH
        }
    }
}
