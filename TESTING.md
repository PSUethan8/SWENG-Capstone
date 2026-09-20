# GridLine Testing Guide

## Automated Sprint 1 coverage

The `GridLineTests` target contains 15 automated tests for the completed Sprint 1 location-tracking work:

| Test cases | Coverage |
| --- | --- |
| TC-01 through TC-03 | Location authorization requests, approval, and denial |
| TC-04 through TC-09 | Starting, restarting, and stopping tracking sessions |
| TC-10 through TC-12 | Location updates, inactive-session behavior, and location errors |
| TC-13 through TC-15 | Required sample fields, speed conversion, and invalid sensor values |

The tests use a mock location provider, so they do not need a live GPS signal or an interactive permission dialog. GitHub Actions runs the suite on an iOS Simulator whenever changes are pushed to `main`, a `test/**` branch, or a `tests/**` branch, and for pull requests.

## Run on GitHub Actions

1. Push a branch to GitHub.
2. Open the repository's **Actions** tab.
3. Select **iOS Automated Tests**.
4. Open the latest workflow run and confirm that **Sprint 1 automated tests** is green.

The workflow can also be started manually with **Run workflow**.

## Run locally on a Mac

1. Open `GridLine.xcodeproj` in Xcode 26.3 or later.
2. Select the **GridLine** scheme and an available iPhone Simulator.
3. Choose **Product > Test**, or press **Command-U**.

The equivalent command-line invocation is:

```sh
xcodebuild \
  -project GridLine.xcodeproj \
  -scheme GridLine \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:GridLineTests \
  CODE_SIGNING_ALLOWED=NO \
  test
```

Change the simulator name if that device is not installed.

## Physical-device checks

The following behaviors still require an iPhone and should be verified manually before release:

- The system location-permission sheet appears and accepts the intended choice.
- Denying permission in iOS Settings produces the expected message in the app.
- Real movement produces plausible coordinates, speed, course, and timestamps.

These checks validate iOS and GPS integration. The corresponding app decision logic is covered by the automated tests.
