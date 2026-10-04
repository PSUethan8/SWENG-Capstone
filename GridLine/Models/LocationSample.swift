//
//  LocationSample.swift
//  GridLine
//
//  Created by Kenton & Ethan.
//

import Foundation
import CoreLocation

struct LocationSample: Identifiable, Equatable {
    let id = UUID()

    let latitude: Double
    let longitude: Double
    let timestamp: Date

    let horizontalAccuracy: Double

    let speedMetersPerSecond: Double?
    let courseDegrees: Double?

    init(location: CLLocation) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.timestamp = location.timestamp

        self.horizontalAccuracy = location.horizontalAccuracy

        // Core Location reports unavailable values as negative numbers.
        // Non-finite values are treated the same way.
        self.speedMetersPerSecond =
            location.speed.isFinite && location.speed >= 0
            ? location.speed
            : nil

        self.courseDegrees =
            location.course.isFinite &&
            location.course >= 0 &&
            location.course < 360
            ? location.course
            : nil
    }

    var speedMPH: Double? {
        guard let speedMetersPerSecond else {
            return nil
        }

        return speedMetersPerSecond * 2.23694
    }

    // MARK: - Validation Helpers

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Finite latitude and longitude within their valid ranges.
    /// Zero latitude and longitude are valid coordinates.
    var hasValidCoordinate: Bool {
        latitude.isFinite &&
        longitude.isFinite &&
        (-90...90).contains(latitude) &&
        (-180...180).contains(longitude)
    }

    /// Finite, nonnegative horizontal accuracy. Core Location uses a
    /// negative accuracy to mark an invalid location.
    var hasValidAccuracy: Bool {
        horizontalAccuracy.isFinite && horizontalAccuracy >= 0
    }

    /// Geodesic distance in meters to another sample.
    func distance(to other: LocationSample) -> CLLocationDistance {
        CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: other.latitude, longitude: other.longitude))
    }
}
