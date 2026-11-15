//
//  RouteReviewCard.swift
//  GridLine
//
//  Created by Kenton & Ethan.
//

import SwiftUI

/// "Recorded Route" card used for the live route and for saved drives.
///
/// Zero-point, single-point and multi-segment routes are presented the same
/// way everywhere: a single point shows only a Start marker, and separate
/// segments are drawn as separate polylines with an explanation.
struct RouteReviewCard: View {

    let segments: [RouteSegmentSnapshot]

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 14
        ) {

            Label(
                "Recorded Route",
                systemImage: "map"
            )
            .font(.headline)
            .accessibilityIdentifier("recordedRoute")

            if segments.isEmpty {

                Text(
                    "No accepted GPS points were recorded for this drive."
                )
                .font(.footnote)
                .foregroundStyle(
                    .secondary
                )
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
                .accessibilityIdentifier("route.empty")

            } else {

                // Small explanation so the user knows how much trusted
                // GPS data actually made it onto the map.
                Text(
                    SessionFormatting.routeDescription(
                        pointCount: pointCount,
                        segmentCount: segments.count
                    )
                )
                .font(.footnote)
                .foregroundStyle(
                    .secondary
                )
                .accessibilityIdentifier("route.description")

                RouteMapView(
                    segments: segments
                )

                if segments.count > 1 {

                    // Multiple route sections mean GPS continuity was broken.
                    // Instead of pretending we know the missing path, we show
                    // the sections separately and explain why.
                    Text(
                        SessionFormatting.routeGapNote
                    )
                    .font(.footnote)
                    .foregroundStyle(
                        .secondary
                    )
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
                    .accessibilityIdentifier("route.gapNote")
                }
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

    private var pointCount: Int {
        segments.reduce(0) {
            $0 + $1.points.count
        }
    }
}
