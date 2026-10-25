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

        // Temporary GPS errors can clear automatically once we get
        // another reliable location.
        case transient

        // Permission problems stay active until access is restored.
        case permission
    }

    // MARK: - Published App State

    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var isTracking = false

    // Keep every reading we receive during the session.
    // This is useful for seeing what Core Location actually gave us,
    // even if some readings are later rejected by our filtering.
    @Published private(set) var samples: [LocationSample] = []

    // Only readings that pass our Sprint 2 processing are stored here.
    // Metrics and Sprint 3 features should use these instead of raw samples.
    @Published private(set) var acceptedSamples: [LocationSample] = []

    // Track why readings were filtered so we can see how often each
    // type of GPS issue occurs.
    @Published private(set) var rejectionCounts: [LocationRejectionReason: Int] = [:]

    @Published private(set) var gpsQuality: GPSQualityState = .inactive

    // Processed speed and direction.
    // nil means we do not currently have a trustworthy value.
    @Published private(set) var movement: MovementMetrics = .unavailable

    // Elapsed time and accepted distance from Sprint 2.
    @Published private(set) var sessionMetrics: SessionMetrics = .zero

    // Sprint 3 summary values.
    // These are built from the same trusted data used by our other metrics.
    @Published private(set) var sessionStatistics: SessionStatistics = .zero

    // Store the route as separate continuous sections instead of one giant line.
    // If GPS drops out and later recovers, a new segment is started so the map
    // does not draw a fake path through an area where we had no reliable data.
    @Published private(set) var routeSegments: [RouteSegment] = []

    @Published private(set) var sessionStartTime: Date?
    @Published private(set) var sessionEndTime: Date?

    @Published private(set) var errorMessage: String?

    // Most recent clock value used by the session.
    // This gets frozen at the session end time after Stop.
    @Published private(set) var currentTime: Date

    // MARK: - Services and Processing

    // We depend on the LocationProviding protocol rather than directly on
    // CLLocationManager. This makes it much easier to swap in mock GPS data
    // during automated testing.
    private let locationService: any LocationProviding

    // Injected clock lets tests control time without actually waiting.
    private let now: () -> Date

    private var locationProcessor: LocationProcessor
    private var movementProcessor: MovementMetricsProcessor
    private var sessionMetricsCalculator: SessionMetricsCalculator

    // Sprint 3 calculator for average speed, max speed, and final summary values.
    private var sessionStatisticsCalculator = SessionStatisticsCalculator()

    private var shouldStartAfterAuthorization = false
    private var isAcquisitionSuspended = false
    private var activeErrorKind: ErrorKind?

    private var clockTask: Task<Void, Never>?

    // Each session gets its own generation number.
    // If an old GPS callback arrives after Stop or after a new session begins,
    // we can safely ignore it instead of letting stale data affect the session.
    nonisolated private let sessionGeneration =
        OSAllocatedUnfairLock(initialState: 0)

    private static let authorizationRequiredMessage =
        "Location access is required before a tracking session can begin."

    private static let permissionLostMessage =
        "Location access was turned off. Allow location access in Settings to resume tracking."

    // MARK: - Initialization

    init(
        locationService: any LocationProviding = LocationService(),
        configuration: LocationProcessingConfiguration = .standard,
        now: @escaping () -> Date = { Date() }
    ) {
        self.locationService = locationService
        self.now = now

        locationProcessor =
            LocationProcessor(configuration: configuration)

        movementProcessor =
            MovementMetricsProcessor(configuration: configuration)

        sessionMetricsCalculator =
            SessionMetricsCalculator(configuration: configuration)

        authorizationStatus =
            locationService.authorizationStatus

        currentTime = now()

        // Core Location callbacks can arrive outside of the SwiftUI flow,
        // so they are routed back through the main actor before changing UI state.

        locationService.onAuthorizationChange = { [weak self] status in
            guard let self else {
                return
            }

            TrackingViewModel.performOnMain { [weak self] in
                self?.handleAuthorizationChange(status)
            }
        }

        locationService.onLocationUpdate = { [weak self] location in
            guard let self else {
                return
            }

            // Capture which session this callback belongs to before
            // it gets dispatched back to the main actor.
            let generation = self.currentGeneration

            TrackingViewModel.performOnMain { [weak self] in
                self?.handleLocationUpdate(
                    location,
                    generation: generation
                )
            }
        }

        locationService.onError = { [weak self] error in
            guard let self else {
                return
            }

            let generation = self.currentGeneration

            TrackingViewModel.performOnMain { [weak self] in
                self?.handleError(
                    error,
                    generation: generation
                )
            }
        }
    }

    // MARK: - Convenience Values

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

    // Processed speed in MPH.
    // nil means we do not currently have a trustworthy speed.
    var currentSpeedMPH: Double? {
        movement.speedMPH
    }

    // Show the accuracy from the latest reading only if Core Location
    // actually gave us a valid accuracy value.
    var currentAccuracyMeters: Double? {
        guard let latestSample,
              latestSample.hasValidAccuracy else {
            return nil
        }

        return latestSample.horizontalAccuracy
    }

    // Useful for telling the user how old the last trusted GPS fix is.
    var secondsSinceLastAcceptedFix: TimeInterval? {
        guard let acceptedAt =
                locationProcessor.lastAcceptedReceivedAt else {
            return nil
        }

        return max(
            0,
            currentTime.timeIntervalSince(acceptedAt)
        )
    }

    // MARK: - Session Control

    func startTracking() {

        // Avoid creating a second session if Start somehow gets triggered twice.
        guard !isTracking else {
            return
        }

        errorMessage = nil

        switch authorizationStatus {

        case .authorizedWhenInUse,
             .authorizedAlways:

            beginSession()

        case .notDetermined:

            // Remember that the user wanted to start.
            // If permission is granted, we can continue automatically.
            shouldStartAfterAuthorization = true

            locationService.requestAuthorization()

        case .denied,
             .restricted:

            shouldStartAfterAuthorization = false

            errorMessage =
                Self.authorizationRequiredMessage

        @unknown default:

            errorMessage =
                "The current location authorization state is unavailable."
        }
    }

    func stopTracking() {

        guard isTracking else {
            return
        }

        // Anything already queued from this session becomes stale after Stop.
        advanceSessionGeneration()

        stopClock()

        locationService.stopUpdatingLocation()

        let endTime = now()

        isTracking = false
        isAcquisitionSuspended = false

        sessionEndTime = endTime
        currentTime = endTime

        gpsQuality = .inactive

        // Freeze the final time and distance.
        sessionMetricsCalculator.stop(at: endTime)

        sessionMetrics =
            sessionMetricsCalculator.metrics(at: endTime)

        // Sprint 3 - make sure the final summary matches the frozen session values.
        refreshSessionStatistics()

        // Live speed/direction no longer mean anything after the drive ends.
        movementProcessor.invalidate()
        movement = .unavailable

        if activeErrorKind != nil {
            activeErrorKind = nil
            errorMessage = nil
        }
    }

    // Called when the app becomes active again.
    // We are not doing background tracking right now, so we re-check
    // permission and time-based GPS state when returning to the app.
    func handleForegroundEntry() {
        handleAuthorizationChange(
            locationService.authorizationStatus
        )

        refreshClock()
    }

    // Recalculate session time even if no new GPS callback has arrived.
    func refreshClock() {
        refreshClock(at: now())
    }

    private func beginSession() {

        guard !isTracking else {
            return
        }

        // New session means old queued callbacks should no longer apply.
        advanceSessionGeneration()

        let startTime = now()

        // Completely clear the previous drive.
        samples.removeAll()
        acceptedSamples.removeAll()
        rejectionCounts.removeAll()

        // Sprint 3 - previous route sections should never carry into a new drive.
        routeSegments.removeAll()

        locationProcessor.reset(
            sessionStartTime: startTime
        )

        movementProcessor.reset()
        movement = .unavailable

        sessionMetricsCalculator.start(
            at: startTime
        )

        sessionMetrics = .zero

        // Sprint 3 - reset all summary values as well.
        sessionStatisticsCalculator.reset()
        sessionStatistics = .zero

        sessionStartTime = startTime
        sessionEndTime = nil
        currentTime = startTime

        errorMessage = nil
        activeErrorKind = nil

        isAcquisitionSuspended = false
        shouldStartAfterAuthorization = false

        // We have started the session, but we still need a trustworthy
        // GPS reading before quality becomes "good."
        gpsQuality = .acquiring

        isTracking = true

        locationService.startUpdatingLocation()

        startClock()
    }

    // MARK: - Callback Handling

    private func handleAuthorizationChange(
        _ status: CLAuthorizationStatus
    ) {
        authorizationStatus = status

        // User originally pressed Start while permission was not determined.
        if shouldStartAfterAuthorization {

            if locationIsAuthorized {

                shouldStartAfterAuthorization = false

                beginSession()

            } else if status == .denied ||
                        status == .restricted {

                shouldStartAfterAuthorization = false

                errorMessage =
                    Self.authorizationRequiredMessage
            }

            return
        }

        // Permission changes outside an active session do not need
        // to change any tracking state.
        guard isTracking else {
            return
        }

        if locationIsAuthorized {

            resumeAcquisitionIfNeeded()

        } else if status == .denied ||
                    status == .restricted {

            suspendAcquisitionForPermission()
        }
    }

    private func handleLocationUpdate(
        _ location: CLLocation,
        generation: Int
    ) {

        // Ignore stale callbacks, updates after Stop, or locations that
        // arrive while acquisition is suspended because permission was lost.
        guard generation == currentGeneration,
              isTracking,
              !isAcquisitionSuspended else {
            return
        }

        let receivedAt = now()

        let sample =
            LocationSample(location: location)

        // Keep the raw reading even if our filtering later rejects it.
        samples.append(sample)

        // Sprint 2 decides whether the reading can actually be trusted.
        let result =
            locationProcessor.process(
                sample: sample,
                receivedAt: receivedAt
            )

        apply(result)

        refreshClock(at: receivedAt)
    }

    private func handleError(
        _ error: Error,
        generation: Int
    ) {

        guard generation == currentGeneration,
              isTracking else {
            return
        }

        if let locationError =
            error as? CLError {

            switch locationError.code {

            case .locationUnknown:

                // Core Location considers this temporary and keeps trying.
                // We keep the session alive, but break continuity so we
                // never calculate movement through the missing GPS period.
                interruptContinuity()

                if gpsQuality != .permissionUnavailable {
                    gpsQuality =
                        .temporarilyUnavailable
                }

                return

            case .denied:

                suspendAcquisitionForPermission()
                return

            case .headingFailure:

                // Heading is not critical enough to end the session.
                return

            default:
                break
            }
        }

        // Do not let another temporary error replace a more important
        // unresolved permission error.
        guard activeErrorKind != .permission else {
            return
        }

        interruptContinuity()

        gpsQuality = .temporarilyUnavailable

        activeErrorKind = .transient

        errorMessage =
            error.localizedDescription
    }

    private func apply(
        _ result: LocationProcessingResult
    ) {

        switch result.disposition {

        case .accepted:

            // At this point the Sprint 2 processor has already decided
            // that the GPS reading is trustworthy enough to use.
            acceptedSamples.append(result.sample)

            // Calculate speed/direction using only trusted data.
            let updatedMovement =
                movementProcessor.update(
                    with: result
                )

            movement = updatedMovement

            // Distance is also calculated only from accepted continuous readings.
            sessionMetricsCalculator.record(
                result
            )

            // Sprint 3 - use processed movement for max speed instead of
            // trusting raw Core Location speed values directly.
            sessionStatisticsCalculator.record(
                updatedMovement
            )

            // Sprint 3 - only accepted readings are allowed onto the map.
            updateRoute(with: result)

            gpsQuality = .good

            // A successful trusted fix clears a temporary GPS error.
            if activeErrorKind == .transient {
                activeErrorKind = nil
                errorMessage = nil
            }

        case .pendingRecovery:

            // This reading looks reasonable, but we are waiting for
            // another reading to confirm the new GPS position.
            break

        case .rejected(let reason):

            rejectionCounts[
                reason,
                default: 0
            ] += 1

            if result.breaksContinuity {

                // Poor GPS should not end the session, but we stop using
                // the previous point as a movement/distance anchor.
                interruptContinuity()

                gpsQuality = .poorAccuracy
            }
        }
    }

    private func refreshClock(
        at time: Date
    ) {

        guard isTracking else {
            return
        }

        currentTime = time

        sessionMetrics =
            sessionMetricsCalculator.metrics(
                at: time
            )

        // Sprint 3 - average speed and final summary values should keep
        // updating even when there is no new GPS reading.
        refreshSessionStatistics()

        // GPS timeout is checked using time rather than waiting for
        // Core Location to explicitly send us an error.
        if !isAcquisitionSuspended &&
            locationProcessor.hasTimedOut(
                at: time
            ) {

            if locationProcessor.hasContinuousSegment {
                interruptContinuity()
            }

            if gpsQuality == .good {
                gpsQuality =
                    .temporarilyUnavailable
            }
        }
    }

    // MARK: - Sprint 3 Statistics and Route

    private func refreshSessionStatistics() {

        // Pull the different session values together into one summary
        // object that the completed-session UI can display.
        sessionStatistics =
            sessionStatisticsCalculator.statistics(
                sessionMetrics: sessionMetrics,
                acceptedSampleCount:
                    acceptedSamples.count,
                rejectedSampleCount:
                    rejectedSampleCount
            )
    }

    private func updateRoute(
        with result: LocationProcessingResult
    ) {

        guard let kind =
                result.acceptanceKind else {
            return
        }

        switch kind {

        case .initialAnchor:

            // First trustworthy point of the drive starts the first route section.
            routeSegments.append(
                RouteSegment(
                    anchor: result.sample
                )
            )

        case .recoveryAnchor:

            // GPS continuity was broken somewhere before this point.
            // Starting a brand-new segment prevents MapKit from drawing
            // a fake straight line across the unknown section.
            routeSegments.append(
                RouteSegment(
                    anchor: result.sample
                )
            )

        case .continuous:

            // Normal trusted locations continue the current route section.
            guard let lastIndex =
                    routeSegments.indices.last else {

                // Defensive fallback in case a continuous reading somehow
                // arrives before we have created a route segment.
                routeSegments.append(
                    RouteSegment(
                        anchor: result.sample
                    )
                )

                return
            }

            var updatedSegments =
                routeSegments

            updatedSegments[lastIndex]
                .append(result.sample)

            // Reassign the array so @Published definitely tells SwiftUI
            // that the map needs to redraw.
            routeSegments =
                updatedSegments
        }
    }

    // MARK: - Continuity and Permission

    private func interruptContinuity() {

        // Once continuity breaks, neither distance nor derived movement
        // should bridge across the unknown section.
        locationProcessor.breakContinuity()

        sessionMetricsCalculator
            .breakContinuity()

        movementProcessor.invalidate()

        movement = .unavailable
    }

    private func suspendAcquisitionForPermission() {

        if !isAcquisitionSuspended {

            isAcquisitionSuspended = true

            locationService
                .stopUpdatingLocation()
        }

        // Losing permission also means we no longer know where the
        // user traveled until permission comes back.
        interruptContinuity()

        gpsQuality =
            .permissionUnavailable

        activeErrorKind =
            .permission

        errorMessage =
            Self.permissionLostMessage
    }

    private func resumeAcquisitionIfNeeded() {

        guard isAcquisitionSuspended ||
              activeErrorKind == .permission else {
            return
        }

        if isAcquisitionSuspended {

            isAcquisitionSuspended = false

            locationService
                .startUpdatingLocation()
        }

        if activeErrorKind == .permission {
            activeErrorKind = nil
            errorMessage = nil
        }

        // Permission is back, but we still need reliable readings
        // before calling GPS quality good again.
        gpsQuality = .acquiring
    }

    // MARK: - Clock

    private func startClock() {

        clockTask?.cancel()

        // Weak self keeps the timer from holding the entire ViewModel alive.
        clockTask = Task { [weak self] in

            while !Task.isCancelled {

                try? await Task.sleep(
                    for: .seconds(1)
                )

                guard let self,
                      !Task.isCancelled else {
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
        sessionGeneration.withLock {
            $0 += 1
        }
    }

    // Core Location callbacks do not always originate from the exact place
    // SwiftUI expects state changes to happen, so make sure our work reaches
    // the main actor before changing anything the interface observes.
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
