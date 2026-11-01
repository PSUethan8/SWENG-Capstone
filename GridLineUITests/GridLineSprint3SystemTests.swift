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

        assertDuration(time, unit: "elapsed")

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

    // MARK: - Helpers

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
        _ element: XCUIElement,
        unit: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let value = element.value as? String ?? ""

        XCTAssertNotNil(
            value.range(
                of: "^[0-9]{2}:[0-9]{2}( \(unit))?$",
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
