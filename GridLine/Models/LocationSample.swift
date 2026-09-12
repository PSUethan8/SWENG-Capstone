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

        self.speedMetersPerSecond =
            location.speed >= 0 ? location.speed : nil

        self.courseDegrees =
            location.course >= 0 ? location.course : nil
    }

    var speedMPH: Double? {
        guard let speedMetersPerSecond else {
            return nil
        }

        return speedMetersPerSecond * 2.23694
    }
}
