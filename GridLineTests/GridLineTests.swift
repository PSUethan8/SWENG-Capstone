//
//  GridLineTests.swift
//  GridLineTests
//
//  Created by Kenton & Ethan.
//

import CoreLocation
import Foundation
import Testing
@testable import GridLine

@Suite("Sprint 1 Automated Tests")
@MainActor
struct GridLineTests {

    // MARK: - US-01 Location Authorization

    @Test("TC-01 requests authorization before starting a session")
    func permissionNotDeterminedRequestsAuthorization() {
        let service = MockLocationService(authorizationStatus: .notDetermined)
        let viewModel = TrackingViewModel(locationService: service)

        viewModel.startTracking()

        #expect(service.requestAuthorizationCallCount == 1)
        #expect(service.startUpdatingLocationCallCount == 0)
        #expect(viewModel.isTracking == false)
        #expect(viewModel.sessionStartTime == nil)
    }

    @Test("TC-02 starts the pending session when authorization is granted")
    func authorizationGrantStartsPendingSession() async {
        let service = MockLocationService(authorizationStatus: .notDetermined)
        let viewModel = TrackingViewModel(locationService: service)

        viewModel.startTracking()
        service.emitAuthorization(.authorizedWhenInUse)
        await settleCallbacks()

        #expect(viewModel.authorizationStatus == .authorizedWhenInUse)
        #expect(viewModel.isTracking)
        #expect(viewModel.sessionStartTime != nil)
        #expect(service.startUpdatingLocationCallCount == 1)
    }

    @Test("TC-03 denied authorization prevents tracking and explains the problem")
    func deniedAuthorizationPreventsTracking() {
        let service = MockLocationService(authorizationStatus: .denied)
        let viewModel = TrackingViewModel(locationService: service)

        viewModel.startTracking()

        #expect(viewModel.isTracking == false)
        #expect(service.requestAuthorizationCallCount == 0)
        #expect(service.startUpdatingLocationCallCount == 0)
        #expect(
            viewModel.errorMessage ==
                "Location access is required before a tracking session can begin."
        )
    }

    // MARK: - US-02 Start Tracking Session

    @Test("TC-04 starting an authorized session initializes session state")
    func authorizedStartInitializesSession() {
        let service = MockLocationService(authorizationStatus: .authorizedWhenInUse)
        let viewModel = TrackingViewModel(locationService: service)

        viewModel.startTracking()

        #expect(viewModel.isTracking)
        #expect(viewModel.sessionStartTime != nil)
        #expect(viewModel.sessionEndTime == nil)
        #expect(viewModel.samples.isEmpty)
        #expect(service.startUpdatingLocationCallCount == 1)
    }

    @Test("TC-05 starting while active does not create a second session")
    func duplicateStartIsIgnored() throws {
        let service = MockLocationService(authorizationStatus: .authorizedAlways)
        let viewModel = TrackingViewModel(locationService: service)

        viewModel.startTracking()
        let originalStartTime = try #require(viewModel.sessionStartTime)
        viewModel.startTracking()

        #expect(viewModel.isTracking)
        #expect(viewModel.sessionStartTime == originalStartTime)
        #expect(service.startUpdatingLocationCallCount == 1)
    }

    @Test("TC-06 a new session clears completed-session state")
    func newSessionClearsPreviousSamplesAndEndTime() async {
        let service = MockLocationService(authorizationStatus: .authorizedWhenInUse)
        let viewModel = TrackingViewModel(locationService: service)

        viewModel.startTracking()
        service.emitLocation(makeLocation(latitude: 40.80, longitude: -77.86))
        await settleCallbacks()
        #expect(viewModel.samples.count == 1)

        viewModel.stopTracking()
        #expect(viewModel.sessionEndTime != nil)

        viewModel.startTracking()

        #expect(viewModel.isTracking)
        #expect(viewModel.samples.isEmpty)
        #expect(viewModel.sessionEndTime == nil)
        #expect(service.startUpdatingLocationCallCount == 2)
    }

    // MARK: - US-03 Stop Tracking Session

    @Test("TC-07 stopping an active session records completion state")
    func stopActiveSessionRecordsEndTime() {
        let service = MockLocationService(authorizationStatus: .authorizedWhenInUse)
        let viewModel = TrackingViewModel(locationService: service)
        viewModel.startTracking()

        viewModel.stopTracking()

        #expect(viewModel.isTracking == false)
        #expect(viewModel.sessionEndTime != nil)
        #expect(service.stopUpdatingLocationCallCount == 1)
    }

    @Test("TC-08 updates received after stopping are ignored")
    func postStopLocationUpdateIsIgnored() async {
        let service = MockLocationService(authorizationStatus: .authorizedWhenInUse)
        let viewModel = TrackingViewModel(locationService: service)
        viewModel.startTracking()
        service.emitLocation(makeLocation(latitude: 40.80, longitude: -77.86))
        await settleCallbacks()
        #expect(viewModel.samples.count == 1)

        viewModel.stopTracking()
        service.emitLocation(makeLocation(latitude: 40.81, longitude: -77.87))
        await settleCallbacks()

        #expect(viewModel.samples.count == 1)
    }

    @Test("TC-09 stopping while inactive is a safe no-op")
    func stopInactiveSessionDoesNothing() {
        let service = MockLocationService(authorizationStatus: .authorizedWhenInUse)
        let viewModel = TrackingViewModel(locationService: service)

        viewModel.stopTracking()

        #expect(viewModel.isTracking == false)
        #expect(viewModel.sessionEndTime == nil)
        #expect(service.stopUpdatingLocationCallCount == 0)
    }

    // MARK: - US-04 Collect Real-Time Location

    @Test("TC-10 active tracking accepts successive location updates")
    func activeSessionAcceptsLocationUpdates() async throws {
        let service = MockLocationService(authorizationStatus: .authorizedWhenInUse)
        let viewModel = TrackingViewModel(locationService: service)
        let first = makeLocation(latitude: 40.801, longitude: -77.861)
        let second = makeLocation(latitude: 40.802, longitude: -77.862)
        viewModel.startTracking()

        service.emitLocation(first)
        await settleCallbacks()
        service.emitLocation(second)
        await settleCallbacks()

        #expect(viewModel.samples.count == 2)
        let latest = try #require(viewModel.latestSample)
        #expect(latest.latitude == second.coordinate.latitude)
        #expect(latest.longitude == second.coordinate.longitude)
    }

    @Test("TC-11 an inactive session ignores location updates")
    func inactiveSessionIgnoresLocationUpdates() async {
        let service = MockLocationService(authorizationStatus: .authorizedWhenInUse)
        let viewModel = TrackingViewModel(locationService: service)

        service.emitLocation(makeLocation(latitude: 40.80, longitude: -77.86))
        await settleCallbacks()

        #expect(viewModel.samples.isEmpty)
    }

    @Test("TC-12 location-service errors are exposed without changing session state")
    func locationErrorIsExposed() async {
        let service = MockLocationService(authorizationStatus: .authorizedWhenInUse)
        let viewModel = TrackingViewModel(locationService: service)
        viewModel.startTracking()

        service.emitError(MockLocationError())
        await settleCallbacks()

        #expect(viewModel.errorMessage == "Simulated location failure")
        #expect(viewModel.isTracking)
    }

    // MARK: - US-05 Create Location Samples

    @Test("TC-13 LocationSample retains required Core Location fields")
    func locationSampleRetainsRequiredFields() {
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let location = makeLocation(
            latitude: 40.801234,
            longitude: -77.861234,
            horizontalAccuracy: 4.25,
            timestamp: timestamp
        )

        let sample = LocationSample(location: location)

        #expect(sample.latitude == 40.801234)
        #expect(sample.longitude == -77.861234)
        #expect(sample.timestamp == timestamp)
        #expect(sample.horizontalAccuracy == 4.25)
    }

    @Test("TC-14 valid speed and course values are retained and converted")
    func validOptionalValuesAreRetained() throws {
        let location = makeLocation(
            latitude: 40.80,
            longitude: -77.86,
            course: 93,
            speed: 10
        )

        let sample = LocationSample(location: location)
        let speedMPH = try #require(sample.speedMPH)

        #expect(sample.speedMetersPerSecond == 10)
        #expect(sample.courseDegrees == 93)
        #expect(abs(speedMPH - 22.3694) < 0.0001)
    }

    @Test("TC-15 invalid negative speed and course values become nil")
    func invalidOptionalValuesBecomeNil() {
        let location = makeLocation(
            latitude: 40.80,
            longitude: -77.86,
            course: -1,
            speed: -1
        )

        let sample = LocationSample(location: location)

        #expect(sample.speedMetersPerSecond == nil)
        #expect(sample.courseDegrees == nil)
        #expect(sample.speedMPH == nil)
    }

    // MARK: - Test Helpers

    private func settleCallbacks() async {
        await Task.yield()
        await Task.yield()
        await Task.yield()
    }

    private func makeLocation(
        latitude: Double,
        longitude: Double,
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
}

private final class MockLocationService: LocationProviding {
    private(set) var authorizationStatus: CLAuthorizationStatus

    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?
    var onLocationUpdate: ((CLLocation) -> Void)?
    var onError: ((Error) -> Void)?

    private(set) var requestAuthorizationCallCount = 0
    private(set) var startUpdatingLocationCallCount = 0
    private(set) var stopUpdatingLocationCallCount = 0

    init(authorizationStatus: CLAuthorizationStatus) {
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

private struct MockLocationError: LocalizedError {
    var errorDescription: String? {
        "Simulated location failure"
    }
}
