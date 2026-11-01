//
//  UITestLocationService.swift
//  GridLine
//
//  Created by Kenton & Ethan.
//

#if DEBUG

import Foundation
import CoreLocation

/// Scripted location provider used only by the UI system tests.
///
/// UI tests set `GRIDLINE_UI_TEST_SCENARIO` in the launch environment so the
/// app can be exercised without live GPS or the system permission sheet.
/// This type is compiled only into Debug builds.
final class UITestLocationService: LocationProviding {

    static let scenarioEnvironmentKey = "GRIDLINE_UI_TEST_SCENARIO"

    enum Scenario: String {

        // No GPS reading ever arrives.
        case empty

        // One valid stationary reading.
        case stationary

        // Four continuous moving readings.
        case moving

        // Two trusted readings followed by a poor-accuracy reading.
        case degraded

        // Trusted readings, a poor-accuracy interruption, then recovery
        // into a second route segment.
        case interrupted
    }

    private struct Reading {
        let latitudeSteps: Double
        let horizontalAccuracy: Double
        let speed: Double
        let course: Double
    }

    // About 11.1 meters of latitude per step.
    private static let latitudeStep = 0.0001

    // Delay between scripted readings.
    private static let readingInterval: Duration = .milliseconds(500)

    let authorizationStatus: CLAuthorizationStatus = .authorizedWhenInUse

    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?
    var onLocationUpdate: ((CLLocation) -> Void)?
    var onError: ((Error) -> Void)?

    private let readings: [Reading]

    private var playbackTask: Task<Void, Never>?

    init(scenario: Scenario) {
        readings = Self.readings(for: scenario)
    }

    /// Returns a scripted service when the UI tests requested a scenario.
    static func fromProcessEnvironment() -> UITestLocationService? {

        guard let name =
                ProcessInfo.processInfo.environment[scenarioEnvironmentKey],
              let scenario = Scenario(rawValue: name) else {
            return nil
        }

        return UITestLocationService(scenario: scenario)
    }

    func requestAuthorization() {
        onAuthorizationChange?(authorizationStatus)
    }

    func startUpdatingLocation() {

        playbackTask?.cancel()

        let readings = readings

        // Replay the scenario from the beginning for every session.
        // Timestamps use the real clock so they pass the same filtering
        // as live Core Location readings.
        playbackTask = Task { [weak self] in

            for reading in readings {

                try? await Task.sleep(
                    for: Self.readingInterval
                )

                guard let self,
                      !Task.isCancelled else {
                    return
                }

                self.onLocationUpdate?(
                    Self.makeLocation(for: reading)
                )
            }
        }
    }

    func stopUpdatingLocation() {
        playbackTask?.cancel()
        playbackTask = nil
    }

    // MARK: - Scenarios

    private static func makeLocation(
        for reading: Reading
    ) -> CLLocation {

        CLLocation(
            coordinate: CLLocationCoordinate2D(
                latitude: 40.8000 + reading.latitudeSteps * latitudeStep,
                longitude: -77.8600
            ),
            altitude: 0,
            horizontalAccuracy: reading.horizontalAccuracy,
            verticalAccuracy: 5,
            course: reading.course,
            speed: reading.speed,
            timestamp: Date()
        )
    }

    private static func readings(
        for scenario: Scenario
    ) -> [Reading] {

        switch scenario {

        case .empty:
            return []

        case .stationary:
            return [
                Reading(latitudeSteps: 0, horizontalAccuracy: 5, speed: 0, course: -1)
            ]

        case .moving:
            return (0..<4).map {
                Reading(latitudeSteps: Double($0), horizontalAccuracy: 5, speed: 10, course: 0)
            }

        case .degraded:
            return [
                Reading(latitudeSteps: 0, horizontalAccuracy: 5, speed: 10, course: 0),
                Reading(latitudeSteps: 1, horizontalAccuracy: 5, speed: 10, course: 0),
                Reading(latitudeSteps: 1, horizontalAccuracy: 80, speed: 10, course: 0)
            ]

        case .interrupted:
            return [
                Reading(latitudeSteps: 0, horizontalAccuracy: 5, speed: 10, course: 0),
                Reading(latitudeSteps: 1, horizontalAccuracy: 5, speed: 10, course: 0),
                Reading(latitudeSteps: 2, horizontalAccuracy: 5, speed: 10, course: 0),
                Reading(latitudeSteps: 3, horizontalAccuracy: 100, speed: 10, course: 0),

                // Pending recovery candidate, recovery anchor, then continuous.
                Reading(latitudeSteps: 10, horizontalAccuracy: 5, speed: 10, course: 0),
                Reading(latitudeSteps: 11, horizontalAccuracy: 5, speed: 10, course: 0),
                Reading(latitudeSteps: 12, horizontalAccuracy: 5, speed: 10, course: 0)
            ]
        }
    }
}

#endif
