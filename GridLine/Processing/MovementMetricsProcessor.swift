//
//  MovementMetricsProcessor.swift
//  GridLine
//
//  Created by Kenton & Ethan.
//

import Foundation

/// Determines usable speed and direction from accepted readings.
///
/// Valid Core Location values are preferred. When they are missing, speed and
/// bearing are derived only from a trustworthy continuous pair of accepted
/// readings, never across an interruption or recovery.
struct MovementMetricsProcessor {

    let configuration: LocationProcessingConfiguration

    private(set) var current: MovementMetrics = .unavailable

    init(configuration: LocationProcessingConfiguration = .standard) {
        self.configuration = configuration
    }

    mutating func reset() {
        current = .unavailable
    }

    /// Clears live movement, for example after a timeout, poor accuracy or
    /// loss of permission.
    mutating func invalidate() {
        current = .unavailable
    }

    /// Updates movement from a processing result. Only accepted readings
    /// change the metrics; other results leave them unchanged.
    @discardableResult
    mutating func update(with result: LocationProcessingResult) -> MovementMetrics {
        guard result.isAccepted else {
            return current
        }

        let sample = result.sample
        let continuousPrevious = result.hasContinuousSegment ? result.previousAcceptedSample : nil
        let derived = continuousPrevious.flatMap { derivedMovement(from: $0, to: sample) }

        var metrics = MovementMetrics()

        if let sensorSpeed = normalizedSpeed(sample.speedMetersPerSecond) {
            metrics.speedMetersPerSecond = sensorSpeed
            metrics.speedSource = .sensor
        } else if let derived {
            metrics.speedMetersPerSecond = derived.speed
            metrics.speedSource = .derived
        }

        // Direction is shown only with evidence of movement above the threshold.
        if let speed = metrics.speedMetersPerSecond,
           speed >= configuration.directionMinimumSpeed {

            if let sensorCourse = normalizedCourse(sample.courseDegrees) {
                metrics.courseDegrees = sensorCourse
                metrics.courseSource = .sensor
            } else if let derived {
                metrics.courseDegrees = derived.bearing
                metrics.courseSource = .derived
            }
        }

        current = metrics

        return metrics
    }

    // MARK: - Normalization

    /// Finite, nonnegative and plausible speed. Zero is a valid stationary value.
    private func normalizedSpeed(_ speed: Double?) -> Double? {
        guard let speed,
              speed.isFinite,
              speed >= 0,
              speed <= configuration.maximumPlausibleSpeed else {
            return nil
        }

        return speed
    }

    /// Finite course in `[0, 360)`. Zero means north and is valid.
    private func normalizedCourse(_ course: Double?) -> Double? {
        guard let course,
              course.isFinite,
              course >= 0,
              course < 360 else {
            return nil
        }

        return course
    }

    // MARK: - Position-Derived Fallback

    private func derivedMovement(
        from previous: LocationSample,
        to current: LocationSample
    ) -> (speed: Double, bearing: Double)? {

        let elapsed = current.timestamp.timeIntervalSince(previous.timestamp)
        let distance = previous.distance(to: current)

        guard elapsed > 0, elapsed.isFinite, distance.isFinite else {
            return nil
        }

        // Ignore displacement that could be GPS jitter.
        let deadband = configuration.distanceDeadband(
            previousAccuracy: previous.horizontalAccuracy,
            currentAccuracy: current.horizontalAccuracy
        )

        guard distance > deadband else {
            return nil
        }

        let speed = distance / elapsed

        guard let plausibleSpeed = normalizedSpeed(speed),
              let bearing = Self.initialBearing(from: previous, to: current) else {
            return nil
        }

        return (plausibleSpeed, bearing)
    }

    /// Initial great-circle bearing in degrees, normalized to `[0, 360)`.
    /// Uses sine and cosine of the longitude difference, so pairs that cross
    /// the date line are handled correctly.
    static func initialBearing(
        from start: LocationSample,
        to end: LocationSample
    ) -> Double? {

        let latitude1 = start.latitude * .pi / 180
        let latitude2 = end.latitude * .pi / 180
        let longitudeDelta = (end.longitude - start.longitude) * .pi / 180

        let y = sin(longitudeDelta) * cos(latitude2)
        let x = cos(latitude1) * sin(latitude2) -
            sin(latitude1) * cos(latitude2) * cos(longitudeDelta)

        guard x.isFinite, y.isFinite, x != 0 || y != 0 else {
            return nil
        }

        var degrees = atan2(y, x) * 180 / .pi
        degrees = degrees.truncatingRemainder(dividingBy: 360)

        if degrees < 0 {
            degrees += 360
        }

        // Guard against rounding producing exactly 360.
        return degrees >= 360 ? 0 : degrees
    }
}
