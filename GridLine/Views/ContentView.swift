//
//  ContentView.swift
//  GridLine
//
//  Created by Kenton & Ethan.
//

import SwiftUI
import CoreLocation

struct ContentView: View {

    @EnvironmentObject private var tracking: TrackingViewModel

    // Sprint 4 - save status of the completed drive and the History entry.
    @EnvironmentObject private var history: SessionHistoryModel

    @Environment(\.dynamicTypeSize)
    private var dynamicTypeSize

    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(spacing: 22) {

                    header

                    trackingStatusCard

                    // Main live values while the drive is running.
                    metrics

                    trackingButton

                    // Sprint 3 - after Stop, give the user one clean place
                    // to review the important values from the drive.
                    if tracking.hasCompletedSession {
                        completedSessionSummary

                        // Sprint 4 - make it clear whether this drive has
                        // reached History yet.
                        if let saveStatus = completedSaveStatus {
                            SaveStatusBanner(
                                status: saveStatus,
                                retry: retryCompletedSave
                            )
                        }
                    }

                    // Sprint 3 - the route can update while tracking and
                    // remains visible after the session is completed.
                    if !tracking.routeSegments.isEmpty {
                        RouteReviewCard(
                            segments:
                                tracking.routeSegments.map(\.snapshot)
                        )
                    }

                    locationDetails

                    if let errorMessage =
                        tracking.errorMessage {

                        errorCard(errorMessage)
                    }
                }
                .padding()
            }
            .background(
                Color(
                    .systemGroupedBackground
                )
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {

                    // Sprint 4 - saved drives can be reviewed at any time,
                    // without location permission.
                    NavigationLink {
                        HistoryListView()
                    } label: {
                        Label(
                            "History",
                            systemImage: "clock.arrow.circlepath"
                        )
                        .labelStyle(.titleAndIcon)
                    }
                    .accessibilityIdentifier("historyButton")
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {

        VStack(spacing: 10) {

            Image(
                systemName:
                    "location.north.circle.fill"
            )
            .font(
                .system(size: 58)
            )
            .symbolRenderingMode(
                .hierarchical
            )
            .foregroundStyle(.blue)

            Text("Gridline")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(
                "Real-Time Vehicle Tracking"
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.top, 16)
    }

    // MARK: - Tracking Status

    private var trackingStatusCard: some View {

        VStack(
            alignment: .leading,
            spacing: 14
        ) {

            HStack {

                VStack(
                    alignment: .leading,
                    spacing: 5
                ) {

                    Text("TRACKING STATUS")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(
                            .secondary
                        )

                    Text(sessionStatusTitle)
                        .font(.title2)
                        .fontWeight(.semibold)
                }

                Spacer()

                Circle()
                    .fill(
                        sessionStatusColor
                    )
                    .frame(
                        width: 14,
                        height: 14
                    )
                    .accessibilityHidden(
                        true
                    )
            }

            // GPS quality matters while tracking, but once the session
            // is complete we do not need to show a live GPS state.
            if tracking.isTracking {
                gpsQualityRow
            }

            Divider()

            HStack {

                Image(
                    systemName:
                        authorizationIcon
                )

                Text(
                    authorizationDescription
                )

                Spacer()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(.background)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20
            )
        )
    }

    private var gpsQualityRow: some View {

        VStack(
            alignment: .leading,
            spacing: 6
        ) {

            Label(
                tracking.gpsQuality.title,
                systemImage:
                    gpsQualityIcon
            )
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(
                gpsQualityColor
            )

            if let guidance =
                tracking.gpsQuality.guidance {

                Text(guidance)
                    .font(.footnote)
                    .foregroundStyle(
                        .secondary
                    )
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
            }
        }
        .accessibilityElement(
            children: .combine
        )
        .accessibilityIdentifier("gpsQuality")
    }

    // MARK: - Live Metrics

    private var metricColumns: [GridItem] {

        // Larger accessibility text gets one card per row
        // so the values do not become cramped.
        let columnCount =
            dynamicTypeSize.isAccessibilitySize
            ? 1
            : 2

        return Array(
            repeating:
                GridItem(
                    .flexible(),
                    spacing: 12
                ),
            count: columnCount
        )
    }

    private var metrics: some View {

        LazyVGrid(
            columns: metricColumns,
            spacing: 12
        ) {

            metricCard(
                title: "Speed",
                value: speedText,
                unit: "MPH",
                icon: "speedometer"
            )

            metricCard(
                title: "Direction",
                value: courseText,
                unit:
                    tracking
                        .movement
                        .compassDirection
                    ?? "direction",
                icon:
                    "location.north.line"
            )

            metricCard(
                title: "Time",
                value:
                    SessionFormatting.duration(
                        tracking
                            .sessionMetrics
                            .elapsedSeconds
                    ),
                unit:
                    tracking.hasCompletedSession
                    ? "final"
                    : "elapsed",
                icon: "stopwatch"
            )

            metricCard(
                title: "Distance",
                value:
                    String(
                        format: "%.2f",
                        tracking
                            .sessionMetrics
                            .totalDistanceMiles
                    ),
                unit:
                    tracking.hasCompletedSession
                    ? "miles (final)"
                    : "miles",
                icon: "road.lanes"
            )

            metricCard(
                title: "Accuracy",
                value: accuracyText,
                unit: "meters (latest)",
                icon: "scope"
            )

            metricCard(
                title: "Samples",
                value:
                    "\(tracking.acceptedSamples.count) / \(tracking.samples.count)",
                unit:
                    "accepted / received",
                icon:
                    "dot.radiowaves.left.and.right"
            )
        }
    }

    private func metricCard(
        title: String,
        value: String,
        unit: String,
        icon: String
    ) -> some View {

        VStack(spacing: 8) {

            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .accessibilityHidden(true)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(unit)
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
                .multilineTextAlignment(
                    .center
                )

            Text(title)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .frame(
            maxWidth: .infinity
        )
        .padding(
            .vertical,
            18
        )
        .padding(
            .horizontal,
            8
        )
        .background(.background)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18
            )
        )
        .accessibilityElement(
            children: .ignore
        )
        .accessibilityLabel(title)
        .accessibilityValue(
            value == "--"
            ? "Unavailable"
            : "\(value) \(unit)"
        )
        .accessibilityIdentifier("metric.\(title)")
    }

    // MARK: - Tracking Button

    private var trackingButton: some View {

        Button {

            if tracking.isTracking {
                tracking.stopTracking()
            } else {
                tracking.startTracking()
            }

        } label: {

            HStack(spacing: 10) {

                Image(
                    systemName:
                        tracking.isTracking
                        ? "stop.fill"
                        : "location.fill"
                )

                Text(
                    tracking.isTracking
                    ? "Stop Tracking"
                    : "Start Tracking"
                )
                .fontWeight(.semibold)
            }
            .frame(
                maxWidth: .infinity
            )
            .padding()
        }
        .buttonStyle(
            .borderedProminent
        )
        .controlSize(.large)
        .tint(
            tracking.isTracking
            ? .red
            : .blue
        )
        .accessibilityIdentifier("trackingButton")
    }

    // MARK: - Sprint 3 Session Summary

    private var completedSessionSummary: some View {

        // Pull this out once so the code below stays easier to read.
        let statistics =
            tracking.sessionStatistics

        return VStack(
            alignment: .leading,
            spacing: 14
        ) {

            Label(
                "Session Summary",
                systemImage:
                    "checkered.flag"
            )
            .font(.headline)
            .accessibilityIdentifier("sessionSummary")

            Divider()

            SessionSummaryRows(
                statistics: statistics
            )
        }
        .padding()
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .background(.background)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20
            )
        )
    }

    // MARK: - Sprint 4 Save Status

    private var completedSaveStatus: SessionHistoryModel.SaveStatus? {
        history.saveStatus(
            for: tracking.lastCompletedSession?.id
        )
    }

    private func retryCompletedSave() {
        guard let id =
                tracking.lastCompletedSession?.id else {
            return
        }

        history.retrySave(id: id)
    }

    // MARK: - Location Details

    private var locationDetails: some View {

        VStack(
            alignment: .leading,
            spacing: 14
        ) {

            Label(
                "Latest Accepted Location",
                systemImage:
                    "mappin.and.ellipse"
            )
            .font(.headline)

            Divider()

            if let sample =
                tracking.latestAcceptedSample {

                if tracking.isTracking &&
                    tracking.gpsQuality != .good {

                    // Keep showing the last trusted location instead of
                    // replacing it with an unreliable current reading.
                    Text(
                        "Last known location. Current GPS readings are not reliable."
                    )
                    .font(.footnote)
                    .foregroundStyle(
                        .orange
                    )
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
                }

                locationRow(
                    title: "Latitude",
                    value:
                        String(
                            format: "%.6f",
                            sample.latitude
                        )
                )

                locationRow(
                    title: "Longitude",
                    value:
                        String(
                            format: "%.6f",
                            sample.longitude
                        )
                )

                locationRow(
                    title: "Accuracy",
                    value:
                        String(
                            format: "%.1f meters",
                            sample
                                .horizontalAccuracy
                        )
                )

                if tracking.isTracking,
                   let age =
                    tracking
                        .secondsSinceLastAcceptedFix {

                    locationRow(
                        title: "Updated",
                        value:
                            freshnessText(age)
                    )
                }

                locationRow(
                    title:
                        "Filtered Readings",
                    value:
                        "\(tracking.rejectedSampleCount)"
                )

            } else {

                Text(
                    tracking.isTracking
                    ? "Waiting for a reliable location..."
                    : "Start a session to begin receiving location data."
                )
                .font(.subheadline)
                .foregroundStyle(
                    .secondary
                )
            }
        }
        .padding()
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .background(.background)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20
            )
        )
    }

    private func locationRow(
        title: String,
        value: String
    ) -> some View {

        HStack {

            Text(title)
                .foregroundStyle(
                    .secondary
                )

            Spacer()

            Text(value)
                .fontWeight(.medium)
                .monospacedDigit()
        }
        .font(.subheadline)
    }

    // MARK: - Error

    private func errorCard(
        _ message: String
    ) -> some View {

        Label(
            message,
            systemImage:
                "exclamationmark.triangle.fill"
        )
        .font(.subheadline)
        .foregroundStyle(.red)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding()
        .background(
            Color.red.opacity(0.08)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 16
            )
        )
    }

    // MARK: - Display Helpers

    private var sessionStatusTitle: String {

        if tracking.isTracking {
            return "Session Active"
        }

        return tracking.hasCompletedSession
            ? "Session Complete"
            : "Ready"
    }

    private var sessionStatusColor: Color {

        guard tracking.isTracking else {
            return .gray
        }

        return tracking.gpsQuality == .good
            ? .green
            : .orange
    }

    private var gpsQualityIcon: String {

        switch tracking.gpsQuality {

        case .inactive:
            return "location.slash"

        case .acquiring:
            return
                "antenna.radiowaves.left.and.right"

        case .good:
            return
                "checkmark.circle.fill"

        case .poorAccuracy:
            return
                "exclamationmark.triangle.fill"

        case .temporarilyUnavailable:
            return
                "antenna.radiowaves.left.and.right.slash"

        case .permissionUnavailable:
            return
                "location.slash.fill"
        }
    }

    private var gpsQualityColor: Color {

        switch tracking.gpsQuality {

        case .inactive:
            return .secondary

        case .acquiring:
            return .blue

        case .good:
            return .green

        case .poorAccuracy,
             .temporarilyUnavailable:

            return .orange

        case .permissionUnavailable:
            return .red
        }
    }

    private var speedText: String {

        guard let speed =
                tracking.currentSpeedMPH else {
            return "--"
        }

        return String(
            format: "%.1f",
            speed
        )
    }

    private var courseText: String {

        guard let course =
                tracking
                    .movement
                    .courseDegrees else {
            return "--"
        }

        return String(
            format: "%.0f°",
            course
        )
    }

    private var accuracyText: String {

        guard let accuracy =
                tracking
                    .currentAccuracyMeters else {
            return "--"
        }

        return String(
            format: "%.1f",
            accuracy
        )
    }

    private func freshnessText(
        _ age: TimeInterval
    ) -> String {

        if age < 1 {
            return "Just now"
        }

        if age < 60 {
            return
                "\(Int(age)) sec ago"
        }

        return
            "\(SessionFormatting.duration(age)) ago"
    }

    private var authorizationDescription: String {

        switch tracking.authorizationStatus {

        case .authorizedAlways:

            return
                "Location Access: Authorized"

        case .authorizedWhenInUse:

            return
                "Location Access: Authorized While Using App"

        case .denied:

            return
                "Location Access: Denied"

        case .restricted:

            return
                "Location Access: Restricted"

        case .notDetermined:

            return
                "Location Access: Not Requested"

        @unknown default:

            return
                "Location Access: Unknown"
        }
    }

    private var authorizationIcon: String {

        tracking.locationIsAuthorized
            ? "checkmark.circle.fill"
            : "location.slash"
    }
}

#Preview {

    let history = SessionHistoryModel(
        store: InMemorySessionStore()
    )

    ContentView()
        .environmentObject(
            TrackingViewModel(
                sessionHistory: history
            )
        )
        .environmentObject(history)
}
