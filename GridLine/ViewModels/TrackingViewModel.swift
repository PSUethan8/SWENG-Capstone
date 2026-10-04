//
//  TrackingViewModel.swift
//  GridLine
//
//  Created by Kenton & Ethan.
//

import Foundation
import CoreLocation
import Combine
import os

@MainActor
final class TrackingViewModel: ObservableObject {

    private enum ErrorKind {
        /// Cleared automatically once a reliable location is accepted.
        case transient

        /// Cleared only when location access is restored.
        case permission
    }

    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var isTracking = false

    /// Every reading received during the session (raw Sprint 1 data).
    @Published private(set) var samples: [LocationSample] = []

    /// Readings accepted by processing. Metrics are calculated only from these.
    @Published private(set) var acceptedSamples: [LocationSample] = []

    /// Number of rejected readings grouped by reason.
    @Published private(set) var rejectionCounts: [LocationRejectionReason: Int] = [:]

    @Published private(set) var gpsQuality: GPSQualityState = .inactive

    /// Processed speed and direction. Unknown values are `nil`, never zero.
    @Published private(set) var movement: MovementMetrics = .unavailable

    @Published private(set) var sessionStartTime: Date?
    @Published private(set) var sessionEndTime: Date?

    @Published private(set) var errorMessage: String?

    /// Clock value from the most recent refresh. Frozen at the end time after Stop.
    @Published private(set) var currentTime: Date

    private let locationService: any LocationProviding
    private let now: () -> Date

    private var locationProcessor: LocationProcessor
    private var movementProcessor: MovementMetricsProcessor

    private var shouldStartAfterAuthorization = false
    private var isAcquisitionSuspended = false
    private var activeErrorKind: ErrorKind?
    private var clockTask: Task<Void, Never>?

    /// Identifies the current session so callbacks queued for an earlier
    /// session are discarded. Read off the main thread, so it is lock-protected.
    nonisolated private let sessionGeneration = OSAllocatedUnfairLock(initialState: 0)

    private static let authorizationRequiredMessage =
        "Location access is required before a tracking session can begin."

    private static let permissionLostMessage =
        "Location access was turned off. Allow location access in Settings to resume tracking."

    init(
        locationService: any LocationProviding = LocationService(),
        configuration: LocationProcessingConfiguration = .standard,
        now: @escaping () -> Date = { Date() }
    ) {
        self.locationService = locationService
        self.now = now
        locationProcessor = LocationProcessor(configuration: configuration)
        movementProcessor = MovementMetricsProcessor(configuration: configuration)
        authorizationStatus = locationService.authorizationStatus
        currentTime = now()

        // Callbacks are delivered on the main thread in order. The session
        // generation is captured before any dispatch so a queued callback from
        // an earlier session cannot affect the current one.
        locationService.onAuthorizationChange = { [weak self] status in
            guard let self else { return }

            TrackingViewModel.performOnMain { [weak self] in
                self?.handleAuthorizationChange(status)
            }
        }

        locationService.onLocationUpdate = { [weak self] location in
            guard let self else { return }

            let generation = self.currentGeneration

            TrackingViewModel.performOnMain { [weak self] in
                self?.handleLocationUpdate(location, generation: generation)
            }
        }

        locationService.onError = { [weak self] error in
            guard let self else { return }

            let generation = self.currentGeneration

            TrackingViewModel.performOnMain { [weak self] in
                self?.handleError(error, generation: generation)
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

    var latestAcceptedSample: LocationSample? {
        acceptedSamples.last
    }

    var rejectedSampleCount: Int {
        rejectionCounts.values.reduce(0, +)
    }

    var hasCompletedSession: Bool {
        !isTracking && sessionEndTime != nil
    }

    /// Processed speed in MPH, or `nil` when speed is unknown.
    var currentSpeedMPH: Double? {
        movement.speedMPH
    }

    /// Accuracy of the latest received reading, or `nil` when it is invalid.
    var currentAccuracyMeters: Double? {
        guard let latestSample, latestSample.hasValidAccuracy else {
            return nil
        }

        return latestSample.horizontalAccuracy
    }

    /// Seconds since the most recent reading was accepted.
    var secondsSinceLastAcceptedFix: TimeInterval? {
        guard let acceptedAt = locationProcessor.lastAcceptedReceivedAt else {
            return nil
        }

        return max(0, currentTime.timeIntervalSince(acceptedAt))
    }

    // MARK: - Session Control

    func startTracking() {
        // A duplicate Start preserves the current session and timer.
        guard !isTracking else {
            return
        }

        errorMessage = nil

        switch authorizationStatus {

        case .authorizedWhenInUse, .authorizedAlways:
            beginSession()

        case .notDetermined:
            shouldStartAfterAuthorization = true
            locationService.requestAuthorization()

        case .denied, .restricted:
            shouldStartAfterAuthorization = false
            errorMessage = Self.authorizationRequiredMessage

        @unknown default:
            errorMessage =
                "The current location authorization state is unavailable."
        }
    }

    func stopTracking() {
        guard isTracking else {
            return
        }

        advanceSessionGeneration()
        stopClock()

        locationService.stopUpdatingLocation()

        let endTime = now()

        isTracking = false
        isAcquisitionSuspended = false
        sessionEndTime = endTime
        currentTime = endTime
        gpsQuality = .inactive

        // Live movement is not meaningful once the session has ended.
        movementProcessor.invalidate()
        movement = .unavailable

        if activeErrorKind != nil {
            activeErrorKind = nil
            errorMessage = nil
        }
    }

    /// Re-evaluates authorization, elapsed time and GPS quality when the app
    /// returns to the foreground. Tracking is not performed in the background.
    func handleForegroundEntry() {
        handleAuthorizationChange(locationService.authorizationStatus)
        refreshClock()
    }

    /// Recomputes time-based state. Called about once per second while a
    /// session is active, independent of GPS callbacks.
    func refreshClock() {
        refreshClock(at: now())
    }

    private func beginSession() {
        guard !isTracking else {
            return
        }

        advanceSessionGeneration()

        let startTime = now()

        samples.removeAll()
        acceptedSamples.removeAll()
        rejectionCounts.removeAll()

        locationProcessor.reset(sessionStartTime: startTime)
        movementProcessor.reset()
        movement = .unavailable

        sessionStartTime = startTime
        sessionEndTime = nil
        currentTime = startTime

        errorMessage = nil
        activeErrorKind = nil
        isAcquisitionSuspended = false
        shouldStartAfterAuthorization = false
        gpsQuality = .acquiring

        isTracking = true

        locationService.startUpdatingLocation()
        startClock()
    }

    // MARK: - Callback Handling

    private func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
        authorizationStatus = status

        if shouldStartAfterAuthorization {
            if locationIsAuthorized {
                shouldStartAfterAuthorization = false
                beginSession()
            } else if status == .denied || status == .restricted {
                shouldStartAfterAuthorization = false
                errorMessage = Self.authorizationRequiredMessage
            }

            return
        }

        guard isTracking else {
            return
        }

        if locationIsAuthorized {
            resumeAcquisitionIfNeeded()
        } else if status == .denied || status == .restricted {
            suspendAcquisitionForPermission()
        }
    }

    private func handleLocationUpdate(_ location: CLLocation, generation: Int) {
        guard generation == currentGeneration,
              isTracking,
              !isAcquisitionSuspended else {
            return
        }

        let receivedAt = now()
        let sample = LocationSample(location: location)

        samples.append(sample)

        let result = locationProcessor.process(sample: sample, receivedAt: receivedAt)
        apply(result)

        refreshClock(at: receivedAt)
    }

    private func handleError(_ error: Error, generation: Int) {
        guard generation == currentGeneration, isTracking else {
            return
        }

        if let locationError = error as? CLError {
            switch locationError.code {

            case .locationUnknown:
                // Temporary: Core Location keeps trying, so acquisition stays
                // subscribed and the session continues.
                interruptContinuity()

                if gpsQuality != .permissionUnavailable {
                    gpsQuality = .temporarilyUnavailable
                }

                return

            case .denied:
                suspendAcquisitionForPermission()
                return

            case .headingFailure:
                return

            default:
                break
            }
        }

        // An unrelated failure must not hide an unresolved permission problem.
        guard activeErrorKind != .permission else {
            return
        }

        interruptContinuity()

        gpsQuality = .temporarilyUnavailable
        activeErrorKind = .transient
        errorMessage = error.localizedDescription
    }

    private func apply(_ result: LocationProcessingResult) {
        switch result.disposition {

        case .accepted:
            acceptedSamples.append(result.sample)
            movement = movementProcessor.update(with: result)
            gpsQuality = .good

            if activeErrorKind == .transient {
                activeErrorKind = nil
                errorMessage = nil
            }

        case .pendingRecovery:
            break

        case .rejected(let reason):
            rejectionCounts[reason, default: 0] += 1

            if result.breaksContinuity {
                interruptContinuity()
                gpsQuality = .poorAccuracy
            }
        }
    }

    private func refreshClock(at time: Date) {
        guard isTracking else {
            return
        }

        currentTime = time

        // No suitable reading within the timeout, even without any callback.
        if !isAcquisitionSuspended && locationProcessor.hasTimedOut(at: time) {
            if locationProcessor.hasContinuousSegment {
                interruptContinuity()
            }

            if gpsQuality == .good {
                gpsQuality = .temporarilyUnavailable
            }
        }
    }

    // MARK: - Continuity and Permission

    /// Breaks the current segment so no movement or distance is calculated
    /// across a gap, and clears live speed and direction.
    private func interruptContinuity() {
        locationProcessor.breakContinuity()

        movementProcessor.invalidate()
        movement = .unavailable
    }

    private func suspendAcquisitionForPermission() {
        if !isAcquisitionSuspended {
            isAcquisitionSuspended = true
            locationService.stopUpdatingLocation()
        }

        interruptContinuity()

        gpsQuality = .permissionUnavailable
        activeErrorKind = .permission
        errorMessage = Self.permissionLostMessage
    }

    private func resumeAcquisitionIfNeeded() {
        guard isAcquisitionSuspended || activeErrorKind == .permission else {
            return
        }

        if isAcquisitionSuspended {
            isAcquisitionSuspended = false
            locationService.startUpdatingLocation()
        }

        if activeErrorKind == .permission {
            activeErrorKind = nil
            errorMessage = nil
        }

        gpsQuality = .acquiring
    }

    // MARK: - Clock

    private func startClock() {
        clockTask?.cancel()

        // Weak capture so the timer never keeps the view model alive.
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))

                guard let self, !Task.isCancelled else {
                    return
                }

                self.refreshClock()
            }
        }
    }

    private func stopClock() {
        clockTask?.cancel()
        clockTask = nil
    }

    // MARK: - Session Generation

    nonisolated private var currentGeneration: Int {
        sessionGeneration.withLock { $0 }
    }

    private func advanceSessionGeneration() {
        sessionGeneration.withLock { $0 += 1 }
    }

    /// Runs `work` on the main actor, synchronously when already on the main
    /// thread so that callbacks are processed in the order they arrive.
    nonisolated private static func performOnMain(
        _ work: @escaping @MainActor @Sendable () -> Void
    ) {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                work()
            }
        } else {
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    work()
                }
            }
        }
    }
}
