//
//  LocationServices.swift
//  GridLine
//
//  Created by Kenton & Ethan.
//

import Foundation
import CoreLocation

final class LocationService: NSObject {

    private let locationManager = CLLocationManager()

    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?
    var onLocationUpdate: ((CLLocation) -> Void)?
    var onError: ((Error) -> Void)?

    override init() {
        super.init()

        locationManager.delegate = self

        // Highest navigation-focused accuracy available through Core Location.
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation

        // Tell iOS that our expected movement type is automotive.
        locationManager.activityType = .automotiveNavigation

        // Receive location updates without requiring a minimum movement distance.
        locationManager.distanceFilter = kCLDistanceFilterNone

        // For our initial testing, we do not want iOS automatically
        // pausing location updates during an active session.
        locationManager.pausesLocationUpdatesAutomatically = false

        authorizationStatus = locationManager.authorizationStatus
    }

    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
}

extension LocationService: CLLocationManagerDelegate {

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        onAuthorizationChange?(manager.authorizationStatus)
    }

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let latestLocation = locations.last else {
            return
        }

        onLocationUpdate?(latestLocation)
    }

    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        onError?(error)
    }
}
