//
//  Sprint2TestSupport.swift
//  GridLineTests
//
//  Created by Kenton & Ethan.
//

import CoreLocation
import Foundation
@testable import GridLine

// MARK: - Location Helpers

func makeTestLocation(
    latitude: Double = 40.8000,
    longitude: Double = -77.8600,
    horizontalAccuracy: Double = 5,
    course: Double = -1,
    speed: Double = -1,
    timestamp: Date = Date()
) -> CLLocation {
    CLLocation(
        coordinate: CLLocationCoordinate2D(
            latitude: latitude,
            longitude: longitude
        ),
        altitude: 0,
        horizontalAccuracy: horizontalAccuracy,
        verticalAccuracy: 5,
        course: course,
        speed: speed,
        timestamp: timestamp
    )
}

func makeTestSample(
    latitude: Double = 40.8000,
    longitude: Double = -77.8600,
    horizontalAccuracy: Double = 5,
    course: Double = -1,
    speed: Double = -1,
    timestamp: Date = Date()
) -> LocationSample {
    LocationSample(
        location: makeTestLocation(
            latitude: latitude,
            longitude: longitude,
            horizontalAccuracy: horizontalAccuracy,
            course: course,
            speed: speed,
            timestamp: timestamp
        )
    )
}

// MARK: - Processing Result Helpers

func makeAcceptedResult(
    sample: LocationSample,
    kind: LocationAcceptanceKind,
    previous: LocationSample? = nil
) -> LocationProcessingResult {

    LocationProcessingResult(
        sample: sample,
        disposition: .accepted(kind),
        previousAcceptedSample: previous
    )
}

func makeRejectedResult(
    sample: LocationSample,
    reason: LocationRejectionReason
) -> LocationProcessingResult {

    LocationProcessingResult(
        sample: sample,
        disposition: .rejected(reason)
    )
}

// MARK: - Controllable Clock

final class TestClock {
    var current: Date

    init(_ current: Date = Date(timeIntervalSince1970: 2_000_000_000)) {
        self.current = current
    }

    func advance(by seconds: TimeInterval) {
        current = current.addingTimeInterval(seconds)
    }
}

// MARK: - Error Helper

struct Sprint2MockError: LocalizedError {

    var errorDescription: String? {
        "Simulated Sprint 2 location failure"
    }
}

// MARK: - Mock Location Service

final class Sprint2MockLocationService: LocationProviding {

    private(set) var authorizationStatus: CLAuthorizationStatus

    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?
    var onLocationUpdate: ((CLLocation) -> Void)?
    var onError: ((Error) -> Void)?

    private(set) var requestAuthorizationCallCount = 0
    private(set) var startUpdatingLocationCallCount = 0
    private(set) var stopUpdatingLocationCallCount = 0

    init(
        authorizationStatus: CLAuthorizationStatus = .authorizedWhenInUse
    ) {
        self.authorizationStatus = authorizationStatus
    }

    func requestAuthorization() {
        requestAuthorizationCallCount += 1
    }

    func startUpdatingLocation() {
        startUpdatingLocationCallCount += 1
    }

    func stopUpdatingLocation() {
        stopUpdatingLocationCallCount += 1
    }

    func emitAuthorization(_ status: CLAuthorizationStatus) {
        authorizationStatus = status
        onAuthorizationChange?(status)
    }

    func emitLocation(_ location: CLLocation) {
        onLocationUpdate?(location)
    }

    func emitError(_ error: Error) {
        onError?(error)
    }
}

func settleSprint2Callbacks() async {
    await Task.yield()
    await Task.yield()
    await Task.yield()
}
