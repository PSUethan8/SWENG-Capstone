//
//  SessionMetricsCalculator.swift
//  GridLine
//
//  Created by Kenton & Ethan.
//

import Foundation

/// Calculates elapsed session time and accumulates distance from accepted
/// readings only.
///
/// Distance uses a separate distance anchor with an accuracy-sensitive
/// deadband. Movement smaller than the deadband leaves the anchor in place,
/// so stationary jitter is ignored while sustained slow movement eventually
/// exceeds the deadband and is counted in full. This is an estimate and may
/// undercount small curves or very slow movement.
struct SessionMetricsCalculator {

    let configuration: LocationProcessingConfiguration

    private(set) var startTime: Date?
    private(set) var endTime: Date?
    private(set) var totalDistanceMeters: Double = 0

    private var distanceAnchor: LocationSample?

    init(configuration: LocationProcessingConfiguration = .standard) {
        self.configuration = configuration
    }

    var isRunning: Bool {
        startTime != nil && endTime == nil
    }

    // MARK: - Session Lifecycle

    mutating func start(at time: Date) {
        startTime = time
        endTime = nil
        totalDistanceMeters = 0
        distanceAnchor = nil
    }

    /// Records the end time once. Repeated calls have no effect.
    mutating func stop(at time: Date) {
        guard isRunning else {
            return
        }

        endTime = time
        distanceAnchor = nil
    }

    mutating func reset() {
        startTime = nil
        endTime = nil
        totalDistanceMeters = 0
        distanceAnchor = nil
    }

    /// Ends the current distance segment so no gap distance is added.
    mutating func breakContinuity() {
        distanceAnchor = nil
    }

    // MARK: - Metrics

    /// Seconds from start to `now` while running, or from start to end after
    /// Stop. Based on timestamp differences, never on timer ticks.
    func elapsedSeconds(at now: Date) -> TimeInterval {
        guard let startTime else {
            return 0
        }

        let elapsed = (endTime ?? now).timeIntervalSince(startTime)

        return elapsed.isFinite ? max(0, elapsed) : 0
    }

    func metrics(at now: Date) -> SessionMetrics {
        SessionMetrics(
            elapsedSeconds: elapsedSeconds(at: now),
            totalDistanceMeters: totalDistanceMeters
        )
    }

    // MARK: - Distance

    /// Adds distance for a continuous accepted reading. First and recovery
    /// anchors contribute zero. Results after Stop are ignored.
    mutating func record(_ result: LocationProcessingResult) {
        guard isRunning, let kind = result.acceptanceKind else {
            return
        }

        let sample = result.sample

        guard kind == .continuous, let anchor = distanceAnchor else {
            distanceAnchor = sample
            return
        }

        let elapsed = sample.timestamp.timeIntervalSince(anchor.timestamp)
        let distance = anchor.distance(to: sample)

        guard elapsed > 0, distance.isFinite, distance >= 0 else {
            distanceAnchor = sample
            return
        }

        let deadband = configuration.distanceDeadband(
            previousAccuracy: anchor.horizontalAccuracy,
            currentAccuracy: sample.horizontalAccuracy
        )

        // Below the deadband: keep the anchor so slow movement accumulates.
        guard distance >= deadband else {
            return
        }

        // The anchor-to-current segment must be plausible on its own.
        guard configuration.isPlausibleMovement(from: anchor, to: sample) else {
            distanceAnchor = sample
            return
        }

        totalDistanceMeters += distance
        distanceAnchor = sample
    }
}
