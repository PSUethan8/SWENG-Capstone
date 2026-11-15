//
//  SessionSummaryRows.swift
//  GridLine
//
//  Created by Kenton & Ethan.
//

import SwiftUI

/// Summary rows shared by the completed-session summary and the saved
/// session detail, so both present the same statistics the same way.
struct SessionSummaryRows: View {

    let statistics: SessionStatistics

    /// Best 0-60 MPH estimate for the drive, or nil when none completed.
    let zeroToSixtySeconds: TimeInterval?

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 14
        ) {

            SummaryRow(
                title: "Elapsed Time",
                value:
                    SessionFormatting.duration(
                        statistics.elapsedSeconds
                    )
            )

            SummaryRow(
                title: "Distance",
                value:
                    SessionFormatting.miles(
                        statistics.totalDistanceMiles
                    )
            )

            SummaryRow(
                title: "Average Speed",
                value:
                    SessionFormatting.averageSpeed(
                        statistics.averageSpeedMPH
                    )
            )

            SummaryRow(
                title: "Maximum Speed",
                value:
                    SessionFormatting.maximumSpeed(
                        statistics.maximumSpeedMPH
                    )
            )

            SummaryRow(
                title: "Best 0–60 MPH",
                value:
                    SessionFormatting.zeroToSixty(
                        zeroToSixtySeconds
                    )
            )

            SummaryRow(
                title: "Accepted Samples",
                value:
                    "\(statistics.acceptedSampleCount)"
            )

            SummaryRow(
                title: "Filtered Readings",
                value:
                    "\(statistics.rejectedSampleCount)"
            )
        }
    }
}

/// One title/value row. Wraps onto two lines at accessibility text sizes
/// so values are never truncated.
struct SummaryRow: View {

    let title: String
    let value: String

    @Environment(\.dynamicTypeSize)
    private var dynamicTypeSize

    var body: some View {

        let layout =
            dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout())

        layout {

            Text(title)
                .foregroundStyle(
                    .secondary
                )

            if !dynamicTypeSize.isAccessibilitySize {
                Spacer()
            }

            Text(value)
                .fontWeight(.semibold)
                .monospacedDigit()
                .accessibilityIdentifier("summary.\(title)")
        }
        .font(.subheadline)
    }
}
