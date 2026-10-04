//
//  SessionMetrics.swift
//  GridLine
//
//  Created by Kenton & Ethan.
//

import Foundation

/// Elapsed time and accepted distance for a tracking session.
struct SessionMetrics: Equatable {

    static let metersPerMile = 1609.344

    static let zero = SessionMetrics(elapsedSeconds: 0, totalDistanceMeters: 0)

    let elapsedSeconds: TimeInterval
    let totalDistanceMeters: Double

    var totalDistanceMiles: Double {
        totalDistanceMeters / Self.metersPerMile
    }
}
