//
//  HistoryListView.swift
//  GridLine
//
//  Created by Kenton & Ethan.
//

import SwiftUI

/// Drives saved on this device, newest first.
///
/// Loading, empty and failure states are distinct, and drives that are
/// still saving or failed to save are listed separately from saved drives.
/// This screen never requests location permission.
struct HistoryListView: View {

    @EnvironmentObject private var history: SessionHistoryModel

    @Environment(\.dynamicTypeSize)
    private var dynamicTypeSize

    var body: some View {

        ScrollView {

            LazyVStack(spacing: 14) {

                if !history.unsavedSessions.isEmpty {
                    unsavedSection
                }

                content
            }
            .padding()
        }
        .background(
            Color(
                .systemGroupedBackground
            )
        )
        .navigationTitle("History")
        .task {
            await history.loadIfNeeded()
        }
        .refreshable {
            await history.reloadHistory()
        }
    }

    // MARK: - States

    @ViewBuilder
    private var content: some View {

        switch history.loadState {

        case .idle, .loading:

            if history.savedSessions.isEmpty {
                loadingState
            } else {
                savedSection
            }

        case .failed(let message):

            failureState(message)

            // Anything confirmed by a later successful save is still shown.
            if !history.savedSessions.isEmpty {
                savedSection
            }

        case .loaded:

            if history.savedSessions.isEmpty {
                emptyState
            } else {
                savedSection
            }
        }
    }

    private var loadingState: some View {

        VStack(spacing: 12) {

            ProgressView()

            Text("Loading saved drives…")
                .font(.subheadline)
                .foregroundStyle(
                    .secondary
                )
        }
        .frame(
            maxWidth: .infinity
        )
        .padding(.vertical, 40)
        .accessibilityElement(
            children: .combine
        )
        .accessibilityIdentifier("history.loading")
    }

    private var emptyState: some View {

        stateCard(
            icon: "clock.arrow.circlepath",
            iconColor: .secondary,
            title: "No saved drives yet",
            message: "Completed drives are saved on this device when you tap Stop Tracking."
        )
        .accessibilityIdentifier("history.empty")
    }

    private func failureState(
        _ message: String
    ) -> some View {

        VStack(spacing: 12) {

            stateCard(
                icon: "exclamationmark.triangle.fill",
                iconColor: .red,
                title: "History couldn't be loaded",
                message: message
            )

            Button {
                Task {
                    await history.reloadHistory()
                }
            } label: {
                Label(
                    "Retry",
                    systemImage: "arrow.clockwise"
                )
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("history.retryLoad")
        }
        .accessibilityElement(
            children: .contain
        )
        .accessibilityIdentifier("history.loadFailed")
    }

    private func stateCard(
        icon: String,
        iconColor: Color,
        title: String,
        message: String
    ) -> some View {

        VStack(spacing: 10) {

            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(iconColor)
                .accessibilityHidden(true)

            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(
                    .secondary
                )
                .multilineTextAlignment(.center)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
        }
        .padding()
        .frame(
            maxWidth: .infinity
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

    // MARK: - Sections

    private var unsavedSection: some View {

        VStack(
            alignment: .leading,
            spacing: 10
        ) {

            sectionHeader("NOT YET SAVED")

            ForEach(history.unsavedSessions) { pending in

                VStack(spacing: 8) {

                    NavigationLink {
                        SessionDetailView(
                            session: pending.session
                        )
                    } label: {
                        sessionRow(pending.session)
                    }
                    .buttonStyle(.plain)

                    SaveStatusBanner(
                        status: pending.status,
                        retry: {
                            history.retrySave(id: pending.id)
                        }
                    )
                }
            }
        }
    }

    private var savedSection: some View {

        VStack(
            alignment: .leading,
            spacing: 10
        ) {

            sectionHeader("SAVED DRIVES")

            ForEach(history.savedSessions) { session in

                NavigationLink {
                    SessionDetailView(
                        session: session
                    )
                } label: {
                    sessionRow(session)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("history.row")
            }
        }
    }

    private func sectionHeader(
        _ title: String
    ) -> some View {

        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(
                .secondary
            )
            .padding(.horizontal, 4)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Row

    private func sessionRow(
        _ session: CompletedSession
    ) -> some View {

        let layout =
            dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 12))

        let duration =
            SessionFormatting.duration(
                session.statistics.elapsedSeconds
            )

        let distance =
            SessionFormatting.miles(
                session.statistics.totalDistanceMiles
            )

        return layout {

            VStack(
                alignment: .leading,
                spacing: 4
            ) {

                Text(
                    SessionFormatting.dateTime(
                        session.startDate
                    )
                )
                .font(.headline)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )

                Label(
                    duration,
                    systemImage: "stopwatch"
                )
                .font(.subheadline)
                .foregroundStyle(
                    .secondary
                )
                .monospacedDigit()
            }

            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: 0)
            }

            Label(
                distance,
                systemImage: "road.lanes"
            )
            .font(.subheadline)
            .fontWeight(.semibold)
            .monospacedDigit()

            if !dynamicTypeSize.isAccessibilitySize {
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
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
        .contentShape(
            RoundedRectangle(
                cornerRadius: 20
            )
        )
        .accessibilityElement(
            children: .ignore
        )
        .accessibilityLabel(
            "Drive on \(SessionFormatting.dateTime(session.startDate))"
        )
        .accessibilityValue(
            "Duration \(duration), distance \(distance)"
        )
        .accessibilityHint("Shows the saved drive details")
    }
}
