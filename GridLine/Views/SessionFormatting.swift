//
//  SessionFormatting.swift
//  GridLine
//
//  Created by Kenton & Ethan.
//

import Foundation

/// Shared presentation formatting for live, completed and saved sessions.
/// Values are stored in SI units and converted only here, at presentation.
enum SessionFormatting {

    /// mm:ss normally, then hh:mm:ss once the duration passes one hour.
    static func duration(
        _ seconds: TimeInterval
    ) -> String {

        let totalSeconds =
            Int(
                max(0, seconds)
            )

        let hours =
            totalSeconds / 3600

        let minutes =
            (totalSeconds % 3600) / 60

        let remainingSeconds =
            totalSeconds % 60

        if hours > 0 {

            return String(
                format:
                    "%02d:%02d:%02d",
                hours,
                minutes,
                remainingSeconds
            )
        }

        return String(
            format: "%02d:%02d",
            minutes,
            remainingSeconds
        )
    }

    static func miles(
        _ miles: Double
    ) -> String {
        String(
            format: "%.2f miles",
            miles
        )
    }

    static func averageSpeed(
        _ mph: Double
    ) -> String {
        String(
            format: "%.1f MPH",
            mph
        )
    }

    /// "--" and zero intentionally mean different things. Zero can be a
    /// real stationary speed, while nil means the session never had a
    /// trustworthy speed value.
    static func maximumSpeed(
        _ mph: Double?
    ) -> String {

        guard let mph else {
            return "-- MPH"
        }

        return String(
            format: "%.1f MPH",
            mph
        )
    }

    /// Date and time a saved drive was recorded, for example
    /// "Nov 15, 2026 at 3:42 PM".
    static func dateTime(
        _ date: Date
    ) -> String {
        date.formatted(
            date: .abbreviated,
            time: .shortened
        )
    }

    static func time(
        _ date: Date
    ) -> String {
        date.formatted(
            date: .omitted,
            time: .shortened
        )
    }

    /// Short description of how many trusted points made it onto the map.
    static func routeDescription(
        pointCount: Int,
        segmentCount: Int
    ) -> String {

        let segmentWord =
            segmentCount == 1
            ? "segment"
            : "segments"

        return
            "\(pointCount) accepted route points across \(segmentCount) \(segmentWord)."
    }

    static let routeGapNote =
        "Separate route sections indicate a GPS interruption or recovery. Gridline does not draw distance across those gaps."
}
