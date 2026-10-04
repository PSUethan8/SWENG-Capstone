//
//  LocationProcessingConfiguration.swift
//  GridLine
//
//  Created by Kenton & Ethan.
//

import Foundation

/// Named policy values used to filter GPS readings and calculate session
/// metrics. These are initial engineering defaults, not empirically tuned
/// sensor settings, so they are injected rather than hard-coded.
struct LocationProcessingConfiguration: Equatable {

    /// Largest horizontal accuracy (meters) a reading may report and still be used.
    var maximumHorizontalAccuracy: Double = 50

    /// Oldest a reading may be (seconds) when compared with the time it was received.
    var maximumSampleAge: TimeInterval = 10

    /// How far (seconds) a reading's timestamp may be ahead of the time it was received.
    var futureTimestampAllowance: TimeInterval = 2

    /// Fastest plausible movement (m/s) between two readings, about 157 MPH.
    /// This is a GPS outlier filter, not a precise vehicle speed limit.
    var maximumPlausibleSpeed: Double = 70

    /// Silence (seconds) without an accepted reading before continuity is broken.
    var locationTimeout: TimeInterval = 10

    /// Slowest speed (m/s) at which a direction of travel is shown.
    var directionMinimumSpeed: Double = 1

    /// Smallest displacement (meters) counted as real movement.
    var distanceNoiseFloor: Double = 3

    /// Largest accuracy-based displacement deadband (meters).
    var distanceNoiseCeiling: Double = 10

    /// Mutually plausible readings required to re-establish a trusted location.
    var recoveryConfirmationCount: Int = 2

    static let standard = LocationProcessingConfiguration()

    /// A configuration is valid when every value is finite and positive, the
    /// deadband range is ordered, and recovery needs more than one reading so
    /// that a single jump can never become a trusted location.
    var isValid: Bool {
        let positiveValues = [
            maximumHorizontalAccuracy,
            maximumSampleAge,
            futureTimestampAllowance,
            maximumPlausibleSpeed,
            locationTimeout,
            directionMinimumSpeed,
            distanceNoiseFloor,
            distanceNoiseCeiling
        ]

        return positiveValues.allSatisfy { $0.isFinite && $0 > 0 } &&
            distanceNoiseFloor <= distanceNoiseCeiling &&
            recoveryConfirmationCount >= 2
    }

    // MARK: - Shared Policy Helpers

    /// Accuracy-sensitive displacement (meters) below which movement is
    /// treated as stationary GPS jitter.
    func distanceDeadband(
        previousAccuracy: Double,
        currentAccuracy: Double
    ) -> Double {
        max(
            distanceNoiseFloor,
            min(distanceNoiseCeiling, max(previousAccuracy, currentAccuracy))
        )
    }

    /// Whether moving from `previous` to `current` is physically plausible,
    /// allowing for the reported accuracy of both readings.
    func isPlausibleMovement(
        from previous: LocationSample,
        to current: LocationSample
    ) -> Bool {
        let elapsed = current.timestamp.timeIntervalSince(previous.timestamp)
        let distance = previous.distance(to: current)

        guard elapsed > 0, elapsed.isFinite, distance.isFinite else {
            return false
        }

        let allowance =
            maximumPlausibleSpeed * elapsed +
            previous.horizontalAccuracy +
            current.horizontalAccuracy

        return allowance.isFinite && distance <= allowance
    }
}
