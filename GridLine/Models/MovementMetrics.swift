//
//  MovementMetrics.swift
//  GridLine
//
//  Created by Kenton & Ethan.
//

import Foundation

/// Processed speed and direction of travel in SI units. A `nil` value means
/// unknown, which is different from a measured speed of zero.
struct MovementMetrics: Equatable {

    enum Source: Equatable {
        /// Reported by Core Location for an accepted reading.
        case sensor

        /// Calculated from two continuous accepted readings.
        case derived
    }

    static let metersPerSecondToMPH = 2.23694

    static let unavailable = MovementMetrics()

    var speedMetersPerSecond: Double?
    var speedSource: Source?

    /// Course over ground in degrees clockwise from true north, `[0, 360)`.
    var courseDegrees: Double?
    var courseSource: Source?

    var speedMPH: Double? {
        guard let speedMetersPerSecond else {
            return nil
        }

        return speedMetersPerSecond * Self.metersPerSecondToMPH
    }

    /// Eight-point compass label for the course, such as "NE".
    var compassDirection: String? {
        guard let courseDegrees else {
            return nil
        }

        let labels = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((courseDegrees + 22.5) / 45) % labels.count

        return labels[index]
    }
}
