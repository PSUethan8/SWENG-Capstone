//
//  GPSQualityState.swift
//  GridLine
//
//  Created by Kenton & Ethan.
//

import Foundation

/// GPS acquisition quality, tracked independently of whether a session is
/// active. A session can remain active while quality is degraded.
enum GPSQualityState: Equatable {
    case inactive
    case acquiring
    case good
    case poorAccuracy
    case temporarilyUnavailable
    case permissionUnavailable

    var title: String {
        switch self {

        case .inactive:
            return "GPS Off"

        case .acquiring:
            return "Waiting for GPS"

        case .good:
            return "GPS Signal Good"

        case .poorAccuracy:
            return "Poor GPS Accuracy"

        case .temporarilyUnavailable:
            return "GPS Temporarily Unavailable"

        case .permissionUnavailable:
            return "Location Access Unavailable"
        }
    }

    /// Plain-language guidance shown while the signal is degraded.
    var guidance: String? {
        switch self {

        case .inactive, .good:
            return nil

        case .acquiring:
            return "Finding your location. Time keeps running; distance starts once a reliable location is found."

        case .poorAccuracy:
            return "Location readings are too imprecise to use. Distance is paused until the signal improves."

        case .temporarilyUnavailable:
            return "GPS signal was lost. Your session is still active and will resume when the signal returns."

        case .permissionUnavailable:
            return "Turn on Location Services and allow Gridline to use your location in Settings. Your session is still active."
        }
    }

    var isDegraded: Bool {
        switch self {

        case .poorAccuracy, .temporarilyUnavailable, .permissionUnavailable:
            return true

        case .inactive, .acquiring, .good:
            return false
        }
    }
}
