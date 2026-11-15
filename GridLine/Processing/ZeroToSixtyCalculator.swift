//
//  ZeroToSixtyCalculator.swift
//  GridLine
//
//  Created by Kenton & Ethan.
//

import Foundation

/// Timing policy for the GPS-based 0–60 MPH estimate. These are initial
/// engineering defaults, injected so they can be tuned during validation.
struct ZeroToSixtyConfiguration: Equatable {

    /// Worst horizontal accuracy (meters) a timing reading may report.
    var maximumHorizontalAccuracy: Double = 20

    /// Speed (MPH) at or below which the vehicle is treated as stopped.
    /// The upward crossing of this value marks the start of a run.
    var standstillSpeedMPH: Double = 1.0

    /// How long (seconds, GPS time) the vehicle must remain at standstill,
    /// across at least two consecutive eligible readings, before a run can start.
    var minimumStandstillDuration: TimeInterval = 1.0

    /// Finish threshold (MPH).
    var targetSpeedMPH: Double = 60.0

    /// Longest gap (seconds, GPS time) allowed between two timing readings.
    var maximumSampleInterval: TimeInterval = 3.0

    static let standard = ZeroToSixtyConfiguration()
}

/// Measures the quickest valid 0–60 MPH run within one drive.
///
/// The calculator consumes accepted readings in order, using only sensor
/// speeds and GPS timestamps. Both threshold crossings are linearly
/// interpolated between the two readings that bracket them. The Start
/// button, display clock and callback arrival times are never used.
///
/// A run must begin from a confirmed standstill and stay within one
/// uninterrupted chain of eligible readings. Any ineligible reading, gap,
/// or continuity break discards the chain and any unfinished attempt, but
/// never the best result already completed in the drive.
struct ZeroToSixtyCalculator {

    enum Phase: Equatable {

        /// Waiting for a qualifying standstill. A vehicle that is already
        /// moving must stop before a run can start.
        case waitingForStandstill

        /// Standstill confirmed. The next upward crossing of the standstill
        /// threshold starts a run.
        case armed

        /// A run is in progress since the interpolated start time.
        case timing(start: Date)
    }

    private struct TimingReading {
        let timestamp: Date
        let speedMPH: Double
    }

    let configuration: ZeroToSixtyConfiguration

    private(set) var phase: Phase = .waitingForStandstill

    /// Quickest completed run in this drive, in raw (unrounded) seconds.
    private(set) var bestDuration: TimeInterval?

    /// Previous eligible reading in the current timing chain.
    private var previous: TimingReading?

    /// GPS timestamp of the first reading in the current standstill run.
    private var standstillStart: Date?

    init(configuration: ZeroToSixtyConfiguration = .standard) {
        self.configuration = configuration
    }

    // MARK: - Lifecycle

    /// Clears everything, including the best result, for a new session.
    mutating func reset() {
        invalidate()
        bestDuration = nil
    }

    /// Breaks the timing chain: discards the previous timing reading,
    /// standstill evidence and any unfinished attempt. The completed best
    /// is kept.
    mutating func invalidate() {
        previous = nil
        standstillStart = nil
        phase = .waitingForStandstill
    }

    // MARK: - Recording

    /// Records one accepted reading.
    ///
    /// - Parameters:
    ///   - timestamp: GPS timestamp of the accepted sample.
    ///   - speedMetersPerSecond: Processed speed for the sample.
    ///   - speedSource: Source of the processed speed. Only `.sensor`
    ///     speeds are eligible; derived speed breaks the chain.
    ///   - horizontalAccuracy: Accuracy of the accepted sample, in meters.
    ///   - acceptanceKind: How the sample was accepted. Initial and recovery
    ///     anchors may seed a new chain but never connect to the previous one.
    /// - Returns: `true` when the best result changed.
    @discardableResult
    mutating func record(
        timestamp: Date,
        speedMetersPerSecond: Double?,
        speedSource: MovementMetrics.Source?,
        horizontalAccuracy: Double,
        acceptanceKind: LocationAcceptanceKind?
    ) -> Bool {

        guard let acceptanceKind,
              speedSource == .sensor,
              let speedMetersPerSecond,
              speedMetersPerSecond.isFinite,
              speedMetersPerSecond >= 0,
              horizontalAccuracy.isFinite,
              horizontalAccuracy >= 0,
              horizontalAccuracy <= configuration.maximumHorizontalAccuracy else {

            invalidate()
            return false
        }

        let current = TimingReading(
            timestamp: timestamp,
            speedMPH: speedMetersPerSecond * MovementMetrics.metersPerSecondToMPH
        )

        // Anchors start a new route section, so they cannot form an
        // interval with whatever came before them.
        if acceptanceKind != .continuous {
            invalidate()
        }

        guard let previous else {
            seed(with: current)
            return false
        }

        let interval =
            current.timestamp.timeIntervalSince(previous.timestamp)

        guard interval.isFinite,
              interval > 0,
              interval <= configuration.maximumSampleInterval else {

            invalidate()
            seed(with: current)
            return false
        }

        let improved = evaluate(from: previous, to: current)

        self.previous = current

        return improved
    }

    // MARK: - State Machine

    /// Starts a new chain from a single reading. One reading alone can
    /// begin standstill evidence but cannot arm or time a run.
    private mutating func seed(with reading: TimingReading) {
        previous = reading
        phase = .waitingForStandstill
        standstillStart =
            isStandstill(reading.speedMPH)
            ? reading.timestamp
            : nil
    }

    private mutating func evaluate(
        from previous: TimingReading,
        to current: TimingReading
    ) -> Bool {

        switch phase {

        case .waitingForStandstill:

            updateStandstill(with: current)
            return false

        case .armed:

            // Still stopped: stay armed.
            guard !isStandstill(current.speedMPH) else {
                return false
            }

            // First upward crossing of the standstill threshold after arming.
            guard let start = crossingTime(
                of: configuration.standstillSpeedMPH,
                from: previous,
                to: current
            ) else {
                invalidate()
                return false
            }

            // One pair can bracket both thresholds.
            if current.speedMPH >= configuration.targetSpeedMPH {
                return finishRun(start: start, from: previous, to: current)
            }

            phase = .timing(start: start)
            return false

        case .timing(let start):

            // Back to standstill before 60 MPH: cancel the attempt and
            // begin a fresh standstill sequence from this reading.
            if isStandstill(current.speedMPH) {
                phase = .waitingForStandstill
                standstillStart = current.timestamp
                return false
            }

            if current.speedMPH >= configuration.targetSpeedMPH {
                return finishRun(start: start, from: previous, to: current)
            }

            return false
        }
    }

    private mutating func updateStandstill(with current: TimingReading) {

        guard isStandstill(current.speedMPH) else {
            standstillStart = nil
            return
        }

        guard let standstillStart else {
            self.standstillStart = current.timestamp
            return
        }

        // Requires at least two consecutive standstill readings, since the
        // first reading of the run has zero elapsed standstill time.
        if current.timestamp.timeIntervalSince(standstillStart) >=
            configuration.minimumStandstillDuration {

            phase = .armed
        }
    }

    /// Completes a run and keeps the smaller raw duration. A new standstill
    /// is required before another run can start.
    private mutating func finishRun(
        start: Date,
        from previous: TimingReading,
        to current: TimingReading
    ) -> Bool {

        phase = .waitingForStandstill
        standstillStart = nil

        guard let finish = crossingTime(
            of: configuration.targetSpeedMPH,
            from: previous,
            to: current
        ) else {
            return false
        }

        let duration = finish.timeIntervalSince(start)

        guard duration.isFinite,
              duration > 0 else {
            return false
        }

        if let bestDuration,
           bestDuration <= duration {
            return false
        }

        bestDuration = duration
        return true
    }

    // MARK: - Helpers

    private func isStandstill(_ speedMPH: Double) -> Bool {
        speedMPH <= configuration.standstillSpeedMPH
    }

    /// Interpolated GPS time at which a rising pair reaches `threshold`.
    /// The fraction is `(threshold - previousSpeed) / (currentSpeed - previousSpeed)`.
    private func crossingTime(
        of threshold: Double,
        from previous: TimingReading,
        to current: TimingReading
    ) -> Date? {

        let speedChange = current.speedMPH - previous.speedMPH

        guard speedChange > 0,
              previous.speedMPH <= threshold,
              current.speedMPH >= threshold else {
            return nil
        }

        let fraction = (threshold - previous.speedMPH) / speedChange

        guard fraction.isFinite,
              (0...1).contains(fraction) else {
            return nil
        }

        let interval =
            current.timestamp.timeIntervalSince(previous.timestamp)

        return previous.timestamp.addingTimeInterval(fraction * interval)
    }
}
