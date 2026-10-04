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

    let configuration: LocationProcessingConfiguration

    private(set) var sessionStartTime: Date?

    /// Most recent accepted reading. Rejected readings never replace it.
    private(set) var lastAcceptedSample: LocationSample?

    /// Latest timestamp of any evaluated reading with a valid timestamp, so an
    /// older reading cannot be accepted after a newer one was rejected.
    private var chronologicalWatermark: Date?

    init(configuration: LocationProcessingConfiguration = .standard) {
        precondition(
            configuration.isValid,
            "LocationProcessingConfiguration contains invalid values."
        )

        self.configuration = configuration
    }

    // MARK: - Session Lifecycle

    mutating func reset(sessionStartTime: Date? = nil) {
        self.sessionStartTime = sessionStartTime
        lastAcceptedSample = nil
        chronologicalWatermark = nil
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

        guard sample.horizontalAccuracy <= configuration.maximumHorizontalAccuracy else {
            return LocationProcessingResult(
                sample: sample,
                disposition: .rejected(.poorAccuracy)
            )
        }

        guard let previous = lastAcceptedSample else {
            lastAcceptedSample = sample

            return LocationProcessingResult(
                sample: sample,
                disposition: .accepted(.initialAnchor)
            )
        }

        // An isolated jump is rejected and leaves the trusted location intact,
        // so the next normal reading can continue from it.
        guard configuration.isPlausibleMovement(from: previous, to: sample) else {
            return LocationProcessingResult(
                sample: sample,
                disposition: .rejected(.implausibleMovement)
            )
        }

        lastAcceptedSample = sample

        return LocationProcessingResult(
            sample: sample,
            disposition: .accepted(.continuous),
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
