//
//  TrackingViewModel.swift
//  GridLine
//
//  Created by Kenton & Ethan.
//

import Foundation
import CoreLocation
import Combine

@MainActor
final class TrackingViewModel: ObservableObject {

    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var isTracking = false

    @Published private(set) var samples: [LocationSample] = []

    @Published private(set) var sessionStartTime: Date?
    @Published private(set) var sessionEndTime: Date?

    @Published private(set) var errorMessage: String?

    private let locationService: any LocationProviding

    private var shouldStartAfterAuthorization = false

    init(locationService: any LocationProviding = LocationService()) {
        self.locationService = locationService
        authorizationStatus = locationService.authorizationStatus

        locationService.onAuthorizationChange = { [weak self] status in
            Task { @MainActor in
                guard let self else { return }

                self.authorizationStatus = status

                if self.shouldStartAfterAuthorization &&
                    self.locationIsAuthorized {

                    self.shouldStartAfterAuthorization = false
                    self.beginSession()
                }
            }
        }

        locationService.onLocationUpdate = { [weak self] location in
            Task { @MainActor in
                guard let self else { return }
                guard self.isTracking else { return }

                let sample = LocationSample(location: location)
                self.samples.append(sample)
            }
        }

        locationService.onError = { [weak self] error in
            Task { @MainActor in
                self?.errorMessage = error.localizedDescription
            }
        }
    }

    var locationIsAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse ||
        authorizationStatus == .authorizedAlways
    }

    var latestSample: LocationSample? {
        samples.last
    }

    var currentSpeedMPH: Double {
        latestSample?.speedMPH ?? 0
    }

    var currentAccuracyMeters: Double? {
        latestSample?.horizontalAccuracy
    }

    func startTracking() {
        errorMessage = nil

        switch authorizationStatus {

        case .authorizedWhenInUse, .authorizedAlways:
            beginSession()

        case .notDetermined:
            shouldStartAfterAuthorization = true
            locationService.requestAuthorization()

        case .denied, .restricted:
            errorMessage =
                "Location access is required before a tracking session can begin."

        @unknown default:
            errorMessage =
                "The current location authorization state is unavailable."
        }
    }

    func stopTracking() {
        guard isTracking else {
            return
        }

        locationService.stopUpdatingLocation()

        isTracking = false
        sessionEndTime = Date()
    }

    private func beginSession() {
        guard !isTracking else {
            return
        }

        samples.removeAll()

        sessionStartTime = Date()
        sessionEndTime = nil

        isTracking = true

        locationService.startUpdatingLocation()
    }
}
