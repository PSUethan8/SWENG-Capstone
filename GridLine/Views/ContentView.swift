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

    var body: some View {
        NavigationStack {

            ScrollView {
                VStack(spacing: 22) {

                    header

                    trackingStatusCard

                    metrics

                    trackingButton

                    locationDetails

                    if let errorMessage = tracking.errorMessage {
                        errorCard(errorMessage)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {

            Image(systemName: "location.north.circle.fill")
                .font(.system(size: 58))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.blue)

            Text("Gridline")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Real-Time Vehicle Tracking")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 16)
    }

    // MARK: - Tracking Status

    private var trackingStatusCard: some View {
        VStack(alignment: .leading, spacing: 14) {

            HStack {

                VStack(alignment: .leading, spacing: 5) {
                    Text("TRACKING STATUS")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    Text(tracking.isTracking ? "Session Active" : "Ready")
                        .font(.title2)
                        .fontWeight(.semibold)
                }

                Spacer()

                Circle()
                    .fill(tracking.isTracking ? Color.green : Color.gray)
                    .frame(width: 14, height: 14)
            }

            Divider()

            HStack {
                Image(systemName: authorizationIcon)

                Text(authorizationDescription)

                Spacer()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Metrics

    private var metrics: some View {
        HStack(spacing: 12) {

            metricCard(
                title: "Speed",
                value: String(format: "%.1f", tracking.currentSpeedMPH),
                unit: "MPH",
                icon: "speedometer"
            )

            metricCard(
                title: "Accuracy",
                value: accuracyText,
                unit: "meters",
                icon: "scope"
            )

            metricCard(
                title: "Samples",
                value: "\(tracking.samples.count)",
                unit: "received",
                icon: "dot.radiowaves.left.and.right"
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

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(title)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 18))
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
            .frame(maxWidth: .infinity)
            .padding()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(tracking.isTracking ? .red : .blue)
    }

    // MARK: - Location Details

    private var locationDetails: some View {
        VStack(alignment: .leading, spacing: 14) {

            Label("Latest Location", systemImage: "mappin.and.ellipse")
                .font(.headline)

            Divider()

            if let sample = tracking.latestSample {

                locationRow(
                    title: "Latitude",
                    value: String(format: "%.6f", sample.latitude)
                )

                locationRow(
                    title: "Longitude",
                    value: String(format: "%.6f", sample.longitude)
                )

                locationRow(
                    title: "Accuracy",
                    value:
                        String(
                            format: "%.1f meters",
                            sample.horizontalAccuracy
                        )
                )

                if let course = sample.courseDegrees {
                    locationRow(
                        title: "Direction",
                        value: String(format: "%.0f°", course)
                    )
                }

            } else {

                Text(
                    tracking.isTracking
                    ? "Waiting for the first location sample..."
                    : "Start a session to begin receiving location data."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func locationRow(
        title: String,
        value: String
    ) -> some View {

        HStack {

            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.medium)
                .monospacedDigit()
        }
        .font(.subheadline)
    }

    // MARK: - Error

    private func errorCard(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                Color.red.opacity(0.08)
            )
            .clipShape(
                RoundedRectangle(cornerRadius: 16)
            )
    }

    // MARK: - Helpers

    private var accuracyText: String {
        guard let accuracy = tracking.currentAccuracyMeters else {
            return "--"
        }

        return String(format: "%.1f", accuracy)
    }

    private var authorizationDescription: String {
        switch tracking.authorizationStatus {

        case .authorizedAlways:
            return "Location Access: Authorized"

        case .authorizedWhenInUse:
            return "Location Access: Authorized While Using App"

        case .denied:
            return "Location Access: Denied"

        case .restricted:
            return "Location Access: Restricted"

        case .notDetermined:
            return "Location Access: Not Requested"

        @unknown default:
            return "Location Access: Unknown"
        }
    }

    private var authorizationIcon: String {
        tracking.locationIsAuthorized
            ? "checkmark.circle.fill"
            : "location.slash"
    }
}

#Preview {
    ContentView()
        .environmentObject(TrackingViewModel())
}
