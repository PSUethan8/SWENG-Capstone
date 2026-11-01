# GridLine Testing Guide

This guide covers automated and manual testing for Sprints 1 through 3.

| Sprint | Stories | Automated case IDs | System case IDs |
| --- | --- | --- | --- |
| Sprint 1 | US-01 to US-05 | TC-01 to TC-15 | — |
| Sprint 2 | FR-06/US-06 to FR-09/US-09 | TC-16 to TC-36 | — |
| Sprint 3 | FR-10/US-10 to FR-13/US-13 | TC-37 to TC-51, TC-53, TC-56 | TC-52, TC-54, TC-55 |

There are 53 automated case IDs in `GridLineTests` and 3 system case IDs. The system cases are automated as UI tests in `GridLineUITests`, but they also have manual steps that UI tests cannot cover: VoiceOver, map drawing, and camera framing. Some case IDs map to more than one executable test. Parameterized tests also count once per argument. The executed test count therefore differs from the number of case IDs. Report the count that Xcode actually executed.

## Execution status

The Sprint 3 tests were written on a Windows machine. The results below are from the first macOS run, after fixing the UI test failures it found (see "First macOS run" under Known observations).

| Item | Result |
| --- | --- |
| Tested commit | `33d2ce0` (branch `tests/sprint3-automated-tests`) |
| Xcode / simulator / iOS | Xcode 27.0 (27A266a) / iPhone 17 Simulator / iOS 27.0 (24A434) |
| Run timestamp | 2026-11-01 18:46 EST (unit and integration), 2026-11-01 18:47 EST (system UI) |
| `GridLineTests` executed / passed / failed / skipped | 57 / 57 / 0 / 0 (55 test functions; TC-47 runs once for each of its 3 arguments) |
| `GridLineSprint3SystemTests` executed / passed / failed / skipped | 9 / 9 / 0 / 0 |
| Overall app coverage | 67.5% of 3,332 executable lines (2,249 covered), from `GridLineTests` only (Sprint 2 historical value: 79.2% of 1,927 executable lines, for comparison only) |
| Per-file coverage: `SessionStatisticsCalculator.swift`, `SessionStatistics.swift`, `RouteSegment.swift`, `TrackingViewModel.swift` | 100% (43/43), 100% (14/14), 100% (11/11), 91.6% (697/761) |
| Physical-device acceptance (UAT-S3-01 to UAT-S3-04) | _pending_ |

## Traceability

### Sprint 1 — `GridLineTests/GridLineTests.swift`

| ID | Story area | Test function |
| --- | --- | --- |
| TC-01 | Authorization | `permissionNotDeterminedRequestsAuthorization` |
| TC-02 | Authorization | `authorizationGrantStartsPendingSession` |
| TC-03 | Authorization | `deniedAuthorizationPreventsTracking` |
| TC-04 | Session start | `authorizedStartInitializesSession` |
| TC-05 | Session start | `duplicateStartIsIgnored` |
| TC-06 | Session restart | `newSessionClearsPreviousSamplesAndEndTime` |
| TC-07 | Session stop | `stopActiveSessionRecordsEndTime` |
| TC-08 | Session stop | `postStopLocationUpdateIsIgnored` |
| TC-09 | Session stop | `stopInactiveSessionDoesNothing` |
| TC-10 | Location updates | `activeSessionAcceptsLocationUpdates` |
| TC-11 | Location updates | `inactiveSessionIgnoresLocationUpdates` |
| TC-12 | Location errors | `locationErrorIsExposed` |
| TC-13 | Sample model | `locationSampleRetainsRequiredFields` |
| TC-14 | Sample model | `validOptionalValuesAreRetained` |
| TC-15 | Sample model | `invalidOptionalValuesBecomeNil` |

### Sprint 2

| ID | Requirement | File | Test function |
| --- | --- | --- | --- |
| TC-16 | FR-06/US-06 | `LocationProcessorTests.swift` | `acceptsInitialTrustedReading` |
| TC-17 | FR-06/US-06 | `LocationProcessorTests.swift` | `rejectsInvalidAndPoorQualityReadings` |
| TC-18 | FR-06/US-06 | `LocationProcessorTests.swift` | `rejectsInvalidTimestamps` |
| TC-19 | FR-06/US-06 | `LocationProcessorTests.swift` | `rejectsOutOfOrderReading` |
| TC-20 | FR-06/US-06 | `LocationProcessorTests.swift` | `rejectsImplausibleJumpWithoutReplacingTrustedLocation` |
| TC-21 | FR-06/US-06 | `LocationProcessorTests.swift` | `confirmsRecoveryAfterContinuityBreak` |
| TC-22 | FR-07/US-07 | `TrackingViewModelSprint2Tests.swift` | `poorAccuracyDoesNotEndSession` |
| TC-23 | FR-07/US-07 | `TrackingViewModelSprint2Tests.swift` | `timeoutMarksGPSUnavailableWithoutEndingSession` |
| TC-24 | FR-07/US-07 | `TrackingViewModelSprint2Tests.swift` | `permissionLossAndRestoreKeepsSessionAlive` |
| TC-25 | FR-07/US-07 | `TrackingViewModelSprint2Tests.swift` | `goodReadingsRestoreGPSAfterInterruption` |
| TC-26 | FR-07/US-07 | `TrackingViewModelSprint2Tests.swift` | `transientErrorClearsAfterRecovery` |
| TC-27 | FR-08/US-08 | `MovementMetricsProcessorTests.swift` | `usesSensorMovementWhenAvailable` |
| TC-28 | FR-08/US-08 | `MovementMetricsProcessorTests.swift` | `derivesMovementFromTrustedLocations` |
| TC-29 | FR-08/US-08 | `MovementMetricsProcessorTests.swift` | `stationaryReadingDoesNotShowDirection` |
| TC-30 | FR-08/US-08 | `MovementMetricsProcessorTests.swift` | `rejectedReadingLeavesMovementUnchanged` |
| TC-31 | FR-08/US-08 | `MovementMetricsProcessorTests.swift` | `recoveryAnchorDoesNotDeriveMovementAcrossGap` |
| TC-32 | FR-09/US-09 | `SessionMetricsCalculatorTests.swift` | `elapsedTimeFreezesAfterStop` |
| TC-33 | FR-09/US-09 | `SessionMetricsCalculatorTests.swift` | `continuousMovementAddsDistance` |
| TC-34 | FR-09/US-09 | `SessionMetricsCalculatorTests.swift` | `jitterIsIgnoredUntilMovementBecomesMeaningful` |
| TC-35 | FR-09/US-09 | `SessionMetricsCalculatorTests.swift` | `interruptionDoesNotAddGapDistance` |
| TC-36 | FR-09/US-09 | `SessionMetricsCalculatorTests.swift` | `postStopReadingsDoNotChangeDistance` |

### Sprint 3

| ID | Type | Requirement | File | Test function(s) |
| --- | --- | --- | --- | --- |
| TC-37 | Unit | FR-10/US-10 | `SessionStatisticsCalculatorTests.swift` | `buildsStatisticsAndConvertsUnits` |
| TC-38 | Unit | FR-10/US-10 | `SessionStatisticsCalculatorTests.swift` | `maximumSpeedIgnoresInvalidValues` |
| TC-39 | Integration | FR-10/US-10 | `TrackingViewModelSprint3StatisticsTests.swift` | `statisticsFreezeAfterStopAndResetOnRestart` |
| TC-49 | Unit | FR-10/US-10 | `SessionStatisticsCalculatorTests.swift` | `boundaryInputsProduceFiniteStatistics` |
| TC-50 | Integration | FR-10/US-10 | `TrackingViewModelSprint3StatisticsTests.swift` | `statisticsUseTrustedCountsAndTotalElapsedTime` |
| TC-40 | Integration | FR-11/US-11 | `TrackingViewModelSprint3LiveTests.swift` | `liveValuesMatchMovingReadings` |
| TC-41 | Integration | FR-11/US-11 | `TrackingViewModelSprint3LiveTests.swift` | `interruptionsClearMovementButKeepSession` |
| TC-42 | Integration | FR-11/US-11 | `TrackingViewModelSprint3LiveTests.swift` | `stationarySpeedDiffersFromUnavailable` |
| TC-51 | Integration | FR-11/US-11 | `TrackingViewModelSprint3LiveTests.swift` | `clockRefreshUpdatesTimeWithoutGPS` |
| TC-52 | System | FR-11/US-11 | `GridLineSprint3SystemTests.swift` (+ `TrackingViewModelSprint3LiveTests.swift`) | `testTC52LiveAndDegradedScreensAtDefaultTextSize`, `testTC52LiveAndDegradedScreensAtAccessibilityTextSize`; supporting unit check `latestAccuracyReflectsRejectedReading`; manual VoiceOver steps |
| TC-43 | Integration | FR-12/US-12 | `TrackingViewModelSprint3SummaryTests.swift` | `completedSummaryMatchesFinalStatistics` |
| TC-44 | Integration | FR-12/US-12 | `TrackingViewModelSprint3SummaryTests.swift` | `completedSummaryStaysFrozen` |
| TC-45 | Integration | FR-12/US-12 | `TrackingViewModelSprint3SummaryTests.swift` | `newSessionClearsPreviousSummary` |
| TC-53 | Integration | FR-12/US-12 | `TrackingViewModelSprint3SummaryTests.swift` | `stopWithoutFixProducesEmptySummary` |
| TC-54 | System | FR-12/US-12 | `GridLineSprint3SystemTests.swift` | `testTC54EmptySessionSummaryPersistsAndClears`, `testTC54MovingSessionSummaryAtDefaultTextSize`, `testTC54MovingSessionSummaryAtAccessibilityTextSize`; manual VoiceOver steps |
| TC-46 | Integration | FR-13/US-13 | `TrackingViewModelSprint3RouteTests.swift` | `continuousReadingsExtendOneSegment` (+ `routeSegmentKeepsIdentifierWhenExtended` model check) |
| TC-47 | Integration | FR-13/US-13 | `TrackingViewModelSprint3RouteTests.swift` | `interruptionStartsSeparateSegment` (3 arguments: timeout, poor accuracy, permission loss) |
| TC-48 | Integration | FR-13/US-13 | `TrackingViewModelSprint3RouteTests.swift` | `rejectedReadingsNeverEnterRoute` |
| TC-55 | System | FR-13/US-13 | `GridLineSprint3SystemTests.swift` | `testTC55RouteHiddenWithoutAcceptedPoints`, `testTC55SinglePointRouteShowsOnlyStart`, `testTC55MultiplePointRouteShowsStartAndEnd`, `testTC55InterruptedRouteShowsSeparateSegments`; manual polyline and camera steps |
| TC-56 | Integration | FR-13/US-13 | `TrackingViewModelSprint3RouteTests.swift` | `completedRouteFreezesAndNewSessionStartsNewRoute` |

The template tests in `GridLineUITests.swift` and `GridLineUITestsLaunchTests.swift` are not counted as requirement coverage.

## Deterministic fixtures

- **Mock location provider.** `Sprint2MockLocationService` in `Sprint2TestSupport.swift` simulates authorization changes, locations, and errors. No live GPS or permission dialog is needed.
- **Controlled clock.** `TestClock` is injected as `TrackingViewModel(now:)`. Tests advance time and call `refreshClock()` instead of sleeping. Location timestamps follow the clock. Gaps stay below the 10 s timeout unless a test is checking the timeout. Steps of about 11.1 m (`sprint3LatitudeStep`) stay above the distance deadband and within the plausibility limit.
- **Queued callbacks.** `emitQueuedLocation` and `emitQueuedError` in `Sprint3TestSupport.swift` deliver a callback from a background thread. The ViewModel tags it with the current session generation and queues it on the main queue. A test can then Stop or restart before it runs. This checks how stale callbacks from an older session are handled. That path differs from ordinary delivery after Stop.
- **Cleanup.** Each Sprint 3 ViewModel test creates its own mock, clock, and ViewModel. Each calls `stopTracking()` in a `defer`, so the one-second clock task never outlives the test.
- **UI scenarios.** `GridLine/Services/UITestLocationService.swift` is compiled only in Debug builds. Setting `GRIDLINE_UI_TEST_SCENARIO` in the launch environment makes the app replay scripted readings 0.5 s apart, timestamped with the real clock. The scenarios are `empty`, `stationary`, `moving`, `degraded`, and `interrupted`. Release builds and normal Debug launches keep using `LocationService`.

## Run locally on a Mac

1. Open `GridLine.xcodeproj` in Xcode 26.3 or later.
2. Select the **GridLine** scheme and an available iPhone Simulator.
3. Choose **Product > Test**, or press **Command-U**. This runs the unit tests and every UI test, including the template tests.

To run the unit and integration tests from the command line with coverage, use a new result-bundle path for each run:

```sh
xcrun simctl list devices available   # pick an iPhone UDID

xcodebuild \
  -project GridLine.xcodeproj \
  -scheme GridLine \
  -destination 'platform=iOS Simulator,id=<UDID>' \
  -only-testing:GridLineTests \
  -enableCodeCoverage YES \
  -resultBundlePath TestResults/Sprint3-Unit-$(date +%Y%m%d-%H%M%S).xcresult \
  CODE_SIGNING_ALLOWED=NO \
  test
```

To run the Sprint 3 system UI tests separately:

```sh
xcodebuild \
  -project GridLine.xcodeproj \
  -scheme GridLine \
  -destination 'platform=iOS Simulator,id=<UDID>' \
  -only-testing:GridLineUITests/GridLineSprint3SystemTests \
  -resultBundlePath TestResults/Sprint3-System-$(date +%Y%m%d-%H%M%S).xcresult \
  CODE_SIGNING_ALLOWED=NO \
  test
```

To read the results and coverage:

```sh
xcrun xcresulttool get test-results summary --path <bundle>.xcresult
xcrun xccov view --report <bundle>.xcresult
xcrun xccov view --report --json <bundle>.xcresult > coverage.json
```

## GitHub Actions

The **iOS Automated Tests** workflow runs on pushes to `main`, `test/**`, `tests/**`, and `feature/**`. It also runs on pull requests and can be started manually. It has two jobs:

- **GridLine unit and integration tests (Sprints 1-3)** runs `GridLineTests` with coverage. Its result bundle, test summary, and coverage report are uploaded as the `unit-test-results` artifact. They are uploaded even when tests fail.
- **GridLine Sprint 3 system UI tests** runs only `GridLineSprint3SystemTests` and uploads `system-test-results`.

Both jobs first check that the configured Xcode (`Xcode_26.3`) is installed on the runner. If it is missing, the job lists the installed versions and fails.

## Manual system checks

Automated UI tests check displayed values, labels, units, visibility, and text size. The checks below need a person. Run them on a simulator using the same scenarios, or on a device. For a simulator, in the scheme's **Run > Arguments > Environment Variables**, set `GRIDLINE_UI_TEST_SCENARIO` to the scenario name.

| ID | Procedure | Expected result |
| --- | --- | --- |
| TC-52 | Turn on VoiceOver. Run `moving`, `stationary`, and `degraded`. Swipe through the status card, every metric card, and Start/Stop. Repeat at the largest accessibility text size. | Each card reads its title and its value with units. `--` is read as "Unavailable". GPS guidance is read in full. In the `degraded` scenario, accuracy reads 80.0 meters (latest), while the latest accepted location still shows the earlier trusted coordinates. Nothing is clipped. Start/Stop stays reachable. |
| TC-54 | Turn on VoiceOver. Complete the `empty` and `moving` scenarios. Swipe through the summary. | All six summary rows are read with their values. The `empty` summary reads "-- MPH" for maximum speed. |
| TC-55 | Look at the map in the `stationary`, `moving`, and `interrupted` scenarios. | `stationary` shows a Start marker, no line, and no End marker. `moving` shows one blue line from Start to End. `interrupted` shows two separate lines with no line across the gap. The camera fits the whole route each time. |

## Physical-device acceptance (UAT)

These require an iPhone. For each, record: device model, iOS version, build or commit, execution timestamp, input/setup, steps, expected result, actual result, pass/fail, and evidence (screenshots or screen recording). Use a passenger or another controlled setup for any check while moving.

| ID | Linked system cases | Procedure | Expected result | Status |
| --- | --- | --- | --- | --- |
| UAT-S3-01 | TC-52, TC-54, TC-55 | Start a session, travel a known short route, then Stop. | Live speed, direction, time, and distance are plausible. The summary freezes at Stop and matches the final values. The map shows the accepted route. | Pending |
| UAT-S3-02 | TC-52, TC-55 | During a session, degrade or interrupt GPS (for example a parking garage, or turning off location access), then recover. | GPS guidance appears. The session continues with the same start time. No distance is added across the gap. A new route section starts after recovery. | Pending |
| UAT-S3-03 | TC-54, TC-55 | Complete and review one session, then start another. | The previous summary and route are cleared when the new session starts. | Pending |
| UAT-S3-04 | TC-52, TC-54, TC-55 | Check zero and unavailable values, a session with no or one route point, the largest text size, and VoiceOver. | Zero shows as 0.0 MPH. Unknown values show as `--`. An empty route hides the map. A single point shows only Start. Everything stays readable. | Pending |

Data is kept only for the current in-memory session. Persistence across app relaunches is out of scope (FR-14).

## Known observations

- `SessionStatisticsCalculator` clamps negative inputs with `max(0, value)`. From reading the code, a NaN input also becomes zero, but an infinite distance would still give an infinite average. No requirement covers non-finite session metrics, so none is tested. This is noted for review only, not verified by a run.
- The route description uses "points" for a count of one ("1 accepted route points"). The UI tests assert the current text.
- **First macOS run (commit `6f45722`).** All unit and integration tests passed. Five system UI tests failed, all because of test code; the app behaved correctly. Fixed in `daab80c` and `33d2ce0`:
  - TC-52 (default text size): `reveal()` always made 30 visibility checks, about 4–5 s per call. The `moving` scenario stops sending readings after about 2 s, so the app's 10 s GPS timeout correctly cleared Direction before the test checked it. `reveal()` now stops as soon as the element is visible.
  - TC-52 (accessibility text size): fast swipes scrolled past the Speed card. `reveal()` now scrolls toward the element with slow swipes.
  - TC-55 (three map tests): on iOS 27 the element labeled with the exact `Marker` title is a sibling of the `Map` element, not a descendant. `mapMarker()` now searches the whole app.
  - A follow-up run then failed TC-54 (empty summary) once: right after the app returns to the foreground, `isHittable` can briefly report false. `reveal()` now asserts the result of the check that ended its loop instead of checking again.
- The `xcodebuild` command for the system UI tests under "Run locally on a Mac" built but never started a test on the first macOS run (Xcode 27.0, stopped after 10 minutes). The system results above were run from Xcode instead. The likely cause is `CODE_SIGNING_ALLOWED=NO` with the UI test runner, but this has not been confirmed.
