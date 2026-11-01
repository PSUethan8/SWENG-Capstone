//
//  GridLineSprint3SystemTests.swift
//  GridLineUITests
//
//  Created by Kenton & Ethan.
//

import XCTest

/// Sprint 3 system tests. Each test launches the app with a scripted location
/// scenario (see `UITestLocationService` in the app target), so no live GPS
/// or permission prompt is needed.
final class GridLineSprint3SystemTests: XCTestCase {

    private static let scenarioEnvironmentKey = "GRIDLINE_UI_TEST_SCENARIO"

    private static let accessibilityTextSize =
        "UICTContentSizeCategoryAccessibilityXXXL"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - TC-52 Live and Degraded Display (FR-11)

    @MainActor
    func testTC52LiveAndDegradedScreensAtDefaultTextSize() throws {
        verifyLiveAndDegradedScreens(contentSize: nil)
    }

    @MainActor
    func testTC52LiveAndDegradedScreensAtAccessibilityTextSize() throws {
        verifyLiveAndDegradedScreens(contentSize: Self.accessibilityTextSize)
    }

    @MainActor
    private func verifyLiveAndDegradedScreens(contentSize: String?) {

        // Live movement with units.
        var app = launchApp(scenario: "moving", contentSize: contentSize)

        startTracking(in: app)

        waitForValue(
            metric("Samples", in: app),
            "4 / 4 accepted / received",
            in: app
        )

        waitForValue(metric("Speed", in: app), "22.4 MPH", in: app)
        waitForValue(metric("Direction", in: app), "0° N", in: app)
        waitForValue(metric("Accuracy", in: app), "5.0 meters (latest)", in: app)

        let time = metric("Time", in: app)
        reveal(time, in: app)

        assertDuration(time.value as? String ?? "", unit: "elapsed")

        assertFitsHorizontally(metric("Speed", in: app), in: app)
        assertFitsHorizontally(metric("Distance", in: app), in: app)

        stopTracking(in: app)

        // A valid stationary speed is 0.0 MPH, not unavailable.
        app = launchApp(scenario: "stationary", contentSize: contentSize)

        startTracking(in: app)

        waitForValue(
            metric("Samples", in: app),
            "1 / 1 accepted / received",
            in: app
        )

        waitForValue(metric("Speed", in: app), "0.0 MPH", in: app)
        waitForValue(metric("Direction", in: app), "Unavailable", in: app)

        stopTracking(in: app)

        // A rejected poor-accuracy reading updates the latest accuracy and
        // GPS guidance, but never shows a misleading zero speed.
        app = launchApp(scenario: "degraded", contentSize: contentSize)

        startTracking(in: app)

        waitForValue(
            metric("Samples", in: app),
            "2 / 3 accepted / received",
            in: app
        )

        waitForValue(metric("Accuracy", in: app), "80.0 meters (latest)", in: app)
        waitForValue(metric("Speed", in: app), "Unavailable", in: app)
        waitForValue(metric("Direction", in: app), "Unavailable", in: app)

        let gpsQuality = element("gpsQuality", in: app)
        reveal(gpsQuality, in: app)

        XCTAssertTrue(gpsQuality.label.contains("Poor GPS Accuracy"))
        XCTAssertTrue(gpsQuality.label.contains("Distance is paused"))
        assertFitsHorizontally(gpsQuality, in: app)

        stopTracking(in: app)
    }

    // MARK: - TC-54 Completed Session Summary (FR-12)

    @MainActor
    func testTC54EmptySessionSummaryPersistsAndClears() throws {

        let app = launchApp(scenario: "empty")

        // No summary before a session has been completed.
        XCTAssertFalse(element("sessionSummary", in: app).exists)

        startTracking(in: app)

        XCTAssertFalse(element("sessionSummary", in: app).exists)

        stopTracking(in: app)

        verifyEmptySummary(in: app)

        waitForValue(metric("Speed", in: app), "Unavailable", in: app)

        let time = metric("Time", in: app)
        reveal(time, in: app)
        assertDuration(time.value as? String ?? "", unit: "final")

        // Leaving and returning keeps the in-memory summary.
        XCUIDevice.shared.press(.home)
        app.activate()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))

        verifyEmptySummary(in: app)

        // A new session clears the summary.
        startTracking(in: app)

        waitForNonExistence(element("sessionSummary", in: app))

        stopTracking(in: app)
    }

    @MainActor
    func testTC54MovingSessionSummaryAtDefaultTextSize() throws {
        verifyMovingSessionSummary(contentSize: nil)
    }

    @MainActor
    func testTC54MovingSessionSummaryAtAccessibilityTextSize() throws {
        verifyMovingSessionSummary(contentSize: Self.accessibilityTextSize)
    }

    @MainActor
    private func verifyMovingSessionSummary(contentSize: String?) {

        let app = launchApp(scenario: "moving", contentSize: contentSize)

        startTracking(in: app)

        waitForValue(
            metric("Samples", in: app),
            "4 / 4 accepted / received",
            in: app
        )

        stopTracking(in: app)

        reveal(element("sessionSummary", in: app), in: app)

        // Three 11.1 meter steps is about 0.02 miles.
        XCTAssertEqual(summaryValue("Distance", in: app), "0.02 miles")
        XCTAssertEqual(summaryValue("Maximum Speed", in: app), "22.4 MPH")
        XCTAssertEqual(summaryValue("Accepted Samples", in: app), "4")
        XCTAssertEqual(summaryValue("Filtered Readings", in: app), "0")

        assertDuration(summaryValue("Elapsed Time", in: app))

        let average = summaryValue("Average Speed", in: app)

        XCTAssertNotNil(
            average.range(
                of: "^[0-9]+\\.[0-9] MPH$",
                options: .regularExpression
            ),
            "Unexpected average speed: \"\(average)\"."
        )

        assertFitsHorizontally(
            element("summary.Maximum Speed", in: app),
            in: app
        )

        // Restarting clears the completed summary.
        startTracking(in: app)

        waitForNonExistence(element("sessionSummary", in: app))

        stopTracking(in: app)
    }

    @MainActor
    private func verifyEmptySummary(in app: XCUIApplication) {

        reveal(element("sessionSummary", in: app), in: app)

        assertDuration(summaryValue("Elapsed Time", in: app))

        XCTAssertEqual(summaryValue("Distance", in: app), "0.00 miles")
        XCTAssertEqual(summaryValue("Average Speed", in: app), "0.0 MPH")

        // Unknown maximum is shown as "--", not as a zero speed.
        XCTAssertEqual(summaryValue("Maximum Speed", in: app), "-- MPH")

        XCTAssertEqual(summaryValue("Accepted Samples", in: app), "0")
        XCTAssertEqual(summaryValue("Filtered Readings", in: app), "0")
    }

    // MARK: - TC-55 Recorded Route (FR-13)

    @MainActor
    func testTC55RouteHiddenWithoutAcceptedPoints() throws {

        let app = launchApp(scenario: "empty")

        startTracking(in: app)

        // Give the scripted service time to prove nothing arrives.
        _ = element("recordedRoute", in: app).waitForExistence(timeout: 2)

        XCTAssertFalse(element("recordedRoute", in: app).exists)

        stopTracking(in: app)

        XCTAssertFalse(element("recordedRoute", in: app).exists)
    }

    @MainActor
    func testTC55SinglePointRouteShowsOnlyStart() throws {

        let app = launchApp(scenario: "stationary")

        startTracking(in: app)

        waitForValue(
            metric("Samples", in: app),
            "1 / 1 accepted / received",
            in: app
        )

        assertRouteDescription(
            "1 accepted route points across 1 segment.",
            in: app
        )

        XCTAssertTrue(mapMarker("Start", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(mapMarker("End", in: app).exists)
        XCTAssertFalse(element("route.gapNote", in: app).exists)

        // The route remains visible after the session is completed.
        stopTracking(in: app)

        assertRouteDescription(
            "1 accepted route points across 1 segment.",
            in: app
        )
    }

    @MainActor
    func testTC55MultiplePointRouteShowsStartAndEnd() throws {

        let app = launchApp(scenario: "moving")

        startTracking(in: app)

        waitForValue(
            metric("Samples", in: app),
            "4 / 4 accepted / received",
            in: app
        )

        stopTracking(in: app)

        assertRouteDescription(
            "4 accepted route points across 1 segment.",
            in: app
        )

        XCTAssertTrue(mapMarker("Start", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(mapMarker("End", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(element("route.gapNote", in: app).exists)
    }

    @MainActor
    func testTC55InterruptedRouteShowsSeparateSegments() throws {

        let app = launchApp(scenario: "interrupted")

        startTracking(in: app)

        // Seven readings: five accepted, one poor-accuracy rejection,
        // and one pending recovery candidate.
        waitForValue(
            metric("Samples", in: app),
            "5 / 7 accepted / received",
            in: app
        )

        stopTracking(in: app)

        assertRouteDescription(
            "5 accepted route points across 2 segments.",
            in: app
        )

        let gapNote = element("route.gapNote", in: app)

        reveal(gapNote, in: app)

        XCTAssertTrue(gapNote.label.contains("does not draw distance across those gaps"))

        XCTAssertTrue(mapMarker("Start", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(mapMarker("End", in: app).waitForExistence(timeout: 5))
    }

    @MainActor
    private func assertRouteDescription(
        _ expected: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let description = element("route.description", in: app)

        reveal(description, in: app, file: file, line: line)

        XCTAssertEqual(description.label, expected, file: file, line: line)
    }

    /// MapKit exposes `Marker` titles as accessibility elements inside the map.
    @MainActor
    private func mapMarker(
        _ title: String,
        in app: XCUIApplication
    ) -> XCUIElement {
        app.maps.firstMatch
            .descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", title))
            .firstMatch
    }

    // MARK: - Helpers

    @MainActor
    private func summaryValue(
        _ title: String,
        in app: XCUIApplication
    ) -> String {

        let value = element("summary.\(title)", in: app)

        reveal(value, in: app)

        return value.label
    }

    @MainActor
    private func waitForNonExistence(
        _ element: XCUIElement,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: element
        )

        XCTAssertEqual(
            XCTWaiter().wait(for: [expectation], timeout: timeout),
            .completed,
            "Expected \(element.identifier) to disappear.",
            file: file,
            line: line
        )
    }

    @MainActor
    private func launchApp(
        scenario: String,
        contentSize: String? = nil
    ) -> XCUIApplication {

        let app = XCUIApplication()

        app.launchEnvironment[Self.scenarioEnvironmentKey] = scenario

        if let contentSize {
            app.launchArguments += [
                "-UIPreferredContentSizeCategoryName",
                contentSize
            ]
        }

        app.launch()

        return app
    }

    @MainActor
    private func element(
        _ identifier: String,
        in app: XCUIApplication
    ) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: identifier)
            .firstMatch
    }

    @MainActor
    private func metric(
        _ title: String,
        in app: XCUIApplication
    ) -> XCUIElement {
        element("metric.\(title)", in: app)
    }

    @MainActor
    private func startTracking(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let button = app.buttons["trackingButton"]

        reveal(button, in: app, file: file, line: line)

        XCTAssertTrue(button.label.contains("Start Tracking"), file: file, line: line)

        button.tap()

        waitForLabel(button, containing: "Stop Tracking", file: file, line: line)
    }

    @MainActor
    private func stopTracking(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let button = app.buttons["trackingButton"]

        reveal(button, in: app, file: file, line: line)

        XCTAssertTrue(button.label.contains("Stop Tracking"), file: file, line: line)

        button.tap()

        waitForLabel(button, containing: "Start Tracking", file: file, line: line)
    }

    /// Scrolls until the element is on screen. Large accessibility text
    /// pushes most of the content below the first screen.
    @MainActor
    private func reveal(
        _ element: XCUIElement,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for _ in 0..<10 where !isVisible(element) {
            app.swipeUp()
        }

        for _ in 0..<20 where !isVisible(element) {
            app.swipeDown()
        }

        XCTAssertTrue(
            isVisible(element),
            "Element \(element) could not be scrolled into view.",
            file: file,
            line: line
        )
    }

    @MainActor
    private func isVisible(_ element: XCUIElement) -> Bool {
        element.exists && element.isHittable
    }

    @MainActor
    private func waitForValue(
        _ element: XCUIElement,
        _ expected: String,
        in app: XCUIApplication,
        timeout: TimeInterval = 8,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        reveal(element, in: app, file: file, line: line)

        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", expected),
            object: element
        )

        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)

        XCTAssertEqual(
            result,
            .completed,
            "Expected \(element.identifier) to show \"\(expected)\" but found \"\(String(describing: element.value))\".",
            file: file,
            line: line
        )
    }

    @MainActor
    private func waitForLabel(
        _ element: XCUIElement,
        containing text: String,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", text),
            object: element
        )

        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)

        XCTAssertEqual(
            result,
            .completed,
            "Expected \(element.identifier) label to contain \"\(text)\" but found \"\(element.label)\".",
            file: file,
            line: line
        )
    }

    /// Sessions under an hour use mm:ss.
    @MainActor
    private func assertDuration(
        _ value: String,
        unit: String? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let suffix = unit.map { " \($0)" } ?? ""

        XCTAssertNotNil(
            value.range(
                of: "^[0-9]{2}:[0-9]{2}\(suffix)$",
                options: .regularExpression
            ),
            "Unexpected duration: \"\(value)\".",
            file: file,
            line: line
        )
    }

    /// Text that runs past the screen edge would be clipped.
    @MainActor
    private func assertFitsHorizontally(
        _ element: XCUIElement,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        reveal(element, in: app, file: file, line: line)

        let window = app.windows.firstMatch.frame
        let frame = element.frame

        XCTAssertGreaterThanOrEqual(frame.minX, window.minX, file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxX, window.maxX, file: file, line: line)
    }
}
