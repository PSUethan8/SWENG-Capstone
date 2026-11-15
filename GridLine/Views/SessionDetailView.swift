//
//  SessionDetailView.swift
//  GridLine
//
//  Created by Kenton & Ethan.
//

import SwiftUI

/// Read-only review of one completed drive, built only from its stored
/// snapshot. It never reads the live tracking state, so a later active
/// drive cannot change what is shown here.
struct SessionDetailView: View {

    let session: CompletedSession

    @EnvironmentObject private var history: SessionHistoryModel

    var body: some View {

        ScrollView {

            VStack(spacing: 22) {

                header

                if let status = unsavedStatus {
                    SaveStatusBanner(
                        status: status,
                        retry: {
                            history.retrySave(id: session.id)
                        }
                    )
                }

                summary

                RouteReviewCard(
                    segments: session.routeSegments
                )
            }
            .padding()
        }
        .background(
            Color(
                .systemGroupedBackground
            )
        )
        .navigationTitle("Saved Drive")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sections

    private var header: some View {

        VStack(
            alignment: .leading,
            spacing: 6
        ) {

            Text("SAVED DRIVE")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(
                    .secondary
                )

            Text(
                SessionFormatting.dateTime(
                    session.startDate
                )
            )
            .font(.title2)
            .fontWeight(.semibold)
            .fixedSize(
                horizontal: false,
                vertical: true
            )
            .accessibilityIdentifier("detail.startDate")

            Text(
                "Started \(SessionFormatting.dateTime(session.startDate)) · Ended \(SessionFormatting.dateTime(session.endDate))"
            )
            .font(.footnote)
            .foregroundStyle(
                .secondary
            )
            .fixedSize(
                horizontal: false,
                vertical: true
            )
            .accessibilityIdentifier("detail.dateRange")
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
        .accessibilityElement(
            children: .combine
        )
    }

    private var summary: some View {

        VStack(
            alignment: .leading,
            spacing: 14
        ) {

            Label(
                "Session Summary",
                systemImage:
                    "checkered.flag"
            )
            .font(.headline)
            .accessibilityIdentifier("detail.summary")

            Divider()

            SessionSummaryRows(
                statistics: session.statistics
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

    /// Present only while this drive has not been saved successfully.
    private var unsavedStatus: SessionHistoryModel.SaveStatus? {
        guard let status = history.saveStatus(for: session.id),
              status != .saved else {
            return nil
        }

        return status
    }
}

/// Shows whether a drive is still saving or failed to save, with Retry.
struct SaveStatusBanner: View {

    let status: SessionHistoryModel.SaveStatus
    let retry: () -> Void

    var body: some View {

        HStack(
            alignment: .firstTextBaseline,
            spacing: 10
        ) {

            switch status {

            case .saving:

                ProgressView()
                    .accessibilityHidden(true)

                Text("Saving to History…")
                    .font(.subheadline)
                    .foregroundStyle(
                        .secondary
                    )

                Spacer(minLength: 0)

            case .saved:

                Label(
                    "Saved to History",
                    systemImage: "checkmark.circle.fill"
                )
                .font(.subheadline)
                .foregroundStyle(.green)

                Spacer(minLength: 0)

            case .failed(let message):

                Label(
                    "Not saved. \(message)",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.subheadline)
                .foregroundStyle(.red)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )

                Spacer(minLength: 0)

                Button("Retry", action: retry)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("history.retrySave")
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
                cornerRadius: 16
            )
        )
        .accessibilityElement(
            children: .contain
        )
        .accessibilityIdentifier("history.saveStatus")
    }
}
