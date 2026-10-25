//
//  RouteSegment.swift
//  GridLine
//
//  Created by Kenton & Ethan
//

import Foundation
import CoreLocation

/// One continuous portion of a recorded route.
///
/// A new segment begins after GPS continuity is broken so the map never
/// connects two locations across an unknown GPS gap.
struct RouteSegment: Identifiable, Equatable {

    let id: UUID
    private(set) var samples: [LocationSample]

    init(
        id: UUID = UUID(),
        anchor: LocationSample
    ) {
        self.id = id
        samples = [anchor]
    }

    mutating func append(_ sample: LocationSample) {
        samples.append(sample)
    }

    var coordinates: [CLLocationCoordinate2D] {
        samples.map(\.coordinate)
    }
}
