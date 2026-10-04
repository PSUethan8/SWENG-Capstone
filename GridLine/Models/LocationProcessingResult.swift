//
//  LocationProcessingResult.swift
//  GridLine
//
//  Created by Kenton & Ethan.
//

import Foundation

/// Why a received GPS reading was not used for session metrics.
enum LocationRejectionReason: String, CaseIterable, Hashable {
    case invalidCoordinate
    case invalidAccuracy
    case poorAccuracy
    case beforeSessionStart
    case staleTimestamp
    case futureTimestamp
    case outOfOrderTimestamp
    case implausibleMovement

    var description: String {
        switch self {

        case .invalidCoordinate:
            return "Invalid coordinates"

        case .invalidAccuracy:
            return "Invalid accuracy"

        case .poorAccuracy:
            return "Poor accuracy"

        case .beforeSessionStart:
            return "Recorded before session start"

        case .staleTimestamp:
            return "Out-of-date reading"

        case .futureTimestamp:
            return "Future timestamp"

        case .outOfOrderTimestamp:
            return "Duplicate or out-of-order reading"

        case .implausibleMovement:
            return "Implausible location jump"
        }
    }
}

/// How an accepted reading relates to the previously accepted reading.
enum LocationAcceptanceKind: Equatable {
    /// First trusted location of the session. Contributes no distance.
    case initialAnchor

    /// Continues an uninterrupted segment from `previousAcceptedSample`.
    case continuous

    /// First trusted location after an interruption or confirmed relocation.
    /// Contributes no distance across the gap.
    case recoveryAnchor
}

enum LocationProcessingDisposition: Equatable {
    case accepted(LocationAcceptanceKind)

    /// Suitable reading held as a recovery candidate until it is confirmed.
    case pendingRecovery

    case rejected(LocationRejectionReason)
}

struct LocationProcessingResult {
    let sample: LocationSample
    let disposition: LocationProcessingDisposition

    /// Previously accepted reading, provided only for a continuous segment.
    let previousAcceptedSample: LocationSample?

    /// Whether this reading interrupted continuity (for example, poor accuracy).
    let breaksContinuity: Bool

    init(
        sample: LocationSample,
        disposition: LocationProcessingDisposition,
        previousAcceptedSample: LocationSample? = nil,
        breaksContinuity: Bool = false
    ) {
        self.sample = sample
        self.disposition = disposition
        self.previousAcceptedSample = previousAcceptedSample
        self.breaksContinuity = breaksContinuity
    }

    var isAccepted: Bool {
        if case .accepted = disposition {
            return true
        }

        return false
    }

    var acceptanceKind: LocationAcceptanceKind? {
        if case .accepted(let kind) = disposition {
            return kind
        }

        return nil
    }

    var rejectionReason: LocationRejectionReason? {
        if case .rejected(let reason) = disposition {
            return reason
        }

        return nil
    }

    /// A continuous segment exists when this reading directly follows a
    /// trusted reading with no interruption in between.
    var hasContinuousSegment: Bool {
        acceptanceKind == .continuous && previousAcceptedSample != nil
    }
}
