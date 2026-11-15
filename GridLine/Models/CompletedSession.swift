//
//  CompletedSession.swift
//  GridLine
//
//  Created by Kenton & Ethan.
//

import Foundation
import CoreLocation

/// Immutable record of one successfully stopped drive.
///
/// The snapshot is captured once at Stop and then owned by the history
/// layer, so a later Start can clear the live session without affecting a
/// save that is still in progress. Distance and speed stay in SI units
/// until presentation.
///
/// Declared `nonisolated` so it can be encoded and decoded off the main
/// actor by the session store.
nonisolated struct CompletedSession: Identifiable, Codable, Equatable, Sendable {

    /// Stable identity assigned when the session actually started.
    /// Saves and retries upsert by this value.
    let id: UUID

    let startDate: Date
    let endDate: Date

    /// Frozen summary values from the Stop path.
    let statistics: SessionStatistics

    /// Accepted route sections in recorded order, including single-point
    /// sections. Empty when the drive had no accepted samples.
    let routeSegments: [RouteSegmentSnapshot]

    /// Quickest valid GPS-based 0–60 MPH estimate in seconds.
    /// `nil` means no valid run was completed. Archives written before
    /// this field existed decode with `nil`.
    let zeroToSixtySeconds: TimeInterval?

    init(
        id: UUID,
        startDate: Date,
        endDate: Date,
        statistics: SessionStatistics,
        routeSegments: [RouteSegmentSnapshot],
        zeroToSixtySeconds: TimeInterval? = nil
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.statistics = statistics
        self.routeSegments = routeSegments
        self.zeroToSixtySeconds = zeroToSixtySeconds
    }

    var routePointCount: Int {
        routeSegments.reduce(0) { $0 + $1.points.count }
    }
}

/// One continuous section of a route, reduced to the values needed to
/// redraw it: the segment's stable identity and its ordered coordinates.
///
/// Used both for saved routes and for presenting the live route, so the
/// map never needs to reconstruct `LocationSample` values.
nonisolated struct RouteSegmentSnapshot: Identifiable, Codable, Equatable, Sendable {

    let id: UUID
    let points: [RoutePoint]

    var coordinates: [CLLocationCoordinate2D] {
        points.map(\.coordinate)
    }
}

nonisolated struct RoutePoint: Codable, Equatable, Sendable {

    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
