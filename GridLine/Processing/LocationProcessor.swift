//
//  LocationProcessor.swift
//  GridLine
//
//  Created by Kenton & Ethan.
//

import Foundation

/// Validates raw GPS readings in chronological order and decides which
/// readings are trustworthy enough to drive session metrics.
///
/// The processor has no knowledge of the UI or of Core Location delivery;
/// callers pass each reading together with the time it was received.
struct LocationProcessor {

    private enum ContinuityState {
        /// No trusted location yet this session.
        case awaitingInitialFix

        /// Readings continue from `lastAcceptedSample`.
        case continuous

        /// Continuity was broken; a new trusted location must be confirmed.
        case reacquiring
    }

    let configuration: LocationProcessingConfiguration

    private(set) var sessionStartTime: Date?

    /// Most recent accepted reading. Rejected readings never replace it.
    private(set) var lastAcceptedSample: LocationSample?

    /// When the most recent reading was accepted. Rejected or pending
    /// readings never refresh it.
    private(set) var lastAcceptedReceivedAt: Date?

    private var continuityState: ContinuityState = .awaitingInitialFix

    /// Latest timestamp of any evaluated reading with a valid timestamp, so an
    /// older reading cannot be accepted after a newer one was rejected.
    private var chronologicalWatermark: Date?

    /// Suitable, mutually plausible readings waiting to confirm a new trusted
    /// location after an interruption or a persistent relocation.
    private var recoveryCandidates: [LocationSample] = []

    init(configuration: LocationProcessingConfiguration = .standard) {
        precondition(
            configuration.isValid,
            "LocationProcessingConfiguration contains invalid values."
        )

        self.configuration = configuration
    }

    // MARK: - Session Lifecycle

    /// Clears every anchor, watermark and candidate for a new session.
    mutating func reset(sessionStartTime: Date? = nil) {
        self.sessionStartTime = sessionStartTime
        lastAcceptedSample = nil
        lastAcceptedReceivedAt = nil
        continuityState = .awaitingInitialFix
        chronologicalWatermark = nil
        recoveryCandidates.removeAll()
    }

    /// Ends the current continuous segment. The next trusted location must be
    /// confirmed and contributes no distance across the gap. Calling this while
    /// already reacquiring keeps any recovery candidates collected so far.
    mutating func breakContinuity() {
        guard continuityState == .continuous else {
            return
        }

        continuityState = .reacquiring
        recoveryCandidates.removeAll()
    }

    var hasContinuousSegment: Bool {
        continuityState == .continuous
    }

    /// Whether no reading has been accepted for longer than the timeout,
    /// measured from the last accepted reading or the session start.
    func hasTimedOut(at now: Date) -> Bool {
        guard let reference = lastAcceptedReceivedAt ?? sessionStartTime else {
            return false
        }

        return now.timeIntervalSince(reference) > configuration.locationTimeout
    }

    // MARK: - Processing

    mutating func process(
        sample: LocationSample,
        receivedAt: Date
    ) -> LocationProcessingResult {

        if let reason = timestampOrCoordinateRejection(for: sample, receivedAt: receivedAt) {
            return LocationProcessingResult(sample: sample, disposition: .rejected(reason))
        }

        chronologicalWatermark = sample.timestamp

        guard sample.hasValidAccuracy else {
            return LocationProcessingResult(
                sample: sample,
                disposition: .rejected(.invalidAccuracy)
            )
        }

        // Poor accuracy interrupts continuity immediately.
        guard sample.horizontalAccuracy <= configuration.maximumHorizontalAccuracy else {
            breakContinuity()
            recoveryCandidates.removeAll()

            return LocationProcessingResult(
                sample: sample,
                disposition: .rejected(.poorAccuracy),
                breaksContinuity: true
            )
        }

        switch continuityState {

        case .awaitingInitialFix:
            return accept(sample, as: .initialAnchor, receivedAt: receivedAt)

        case .continuous:
            return processContinuous(sample, receivedAt: receivedAt)

        case .reacquiring:
            return processRecoveryCandidate(sample, receivedAt: receivedAt)
        }
    }

    private mutating func processContinuous(
        _ sample: LocationSample,
        receivedAt: Date
    ) -> LocationProcessingResult {

        guard let previous = lastAcceptedSample else {
            return accept(sample, as: .initialAnchor, receivedAt: receivedAt)
        }

        if configuration.isPlausibleMovement(from: previous, to: sample) {
            recoveryCandidates.removeAll()

            return accept(
                sample,
                as: .continuous,
                receivedAt: receivedAt,
                previous: previous
            )
        }

        // An isolated jump is rejected and leaves the trusted location intact,
        // so the next normal reading can continue from it. If enough later
        // readings agree with each other but not with the trusted location,
        // treat it as a genuine relocation (or a bad earlier fix) instead of
        // rejecting every future reading.
        if addRecoveryCandidate(sample) {
            return accept(sample, as: .recoveryAnchor, receivedAt: receivedAt)
        }

        return LocationProcessingResult(
            sample: sample,
            disposition: .rejected(.implausibleMovement)
        )
    }

    private mutating func processRecoveryCandidate(
        _ sample: LocationSample,
        receivedAt: Date
    ) -> LocationProcessingResult {

        if addRecoveryCandidate(sample) {
            return accept(sample, as: .recoveryAnchor, receivedAt: receivedAt)
        }

        return LocationProcessingResult(sample: sample, disposition: .pendingRecovery)
    }

    /// Adds a suitable reading to the recovery chain. A reading that is not
    /// plausible from the previous candidate starts a new chain.
    /// Returns `true` once enough mutually plausible readings are collected.
    private mutating func addRecoveryCandidate(_ sample: LocationSample) -> Bool {
        if let lastCandidate = recoveryCandidates.last,
           !configuration.isPlausibleMovement(from: lastCandidate, to: sample) {
            recoveryCandidates.removeAll()
        }

        recoveryCandidates.append(sample)

        return recoveryCandidates.count >= configuration.recoveryConfirmationCount
    }

    private mutating func accept(
        _ sample: LocationSample,
        as kind: LocationAcceptanceKind,
        receivedAt: Date,
        previous: LocationSample? = nil
    ) -> LocationProcessingResult {

        lastAcceptedSample = sample
        lastAcceptedReceivedAt = receivedAt
        continuityState = .continuous
        recoveryCandidates.removeAll()

        return LocationProcessingResult(
            sample: sample,
            disposition: .accepted(kind),
            previousAcceptedSample: previous
        )
    }

    // MARK: - Validation

    private func timestampOrCoordinateRejection(
        for sample: LocationSample,
        receivedAt: Date
    ) -> LocationRejectionReason? {

        guard sample.hasValidCoordinate else {
            return .invalidCoordinate
        }

        if let sessionStartTime, sample.timestamp < sessionStartTime {
            return .beforeSessionStart
        }

        let age = receivedAt.timeIntervalSince(sample.timestamp)

        guard age.isFinite else {
            return .staleTimestamp
        }

        if age > configuration.maximumSampleAge {
            return .staleTimestamp
        }

        if -age > configuration.futureTimestampAllowance {
            return .futureTimestamp
        }

        if let chronologicalWatermark, sample.timestamp <= chronologicalWatermark {
            return .outOfOrderTimestamp
        }

        return nil
    }
}
