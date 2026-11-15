//
//  SessionHistoryModel.swift
//  GridLine
//
//  Created by Kenton & Ethan.
//

import Foundation
import Combine

/// Owns the on-device drive history and the save lifecycle of completed
/// sessions. Created once in the app composition layer and shared by the
/// tracking flow (which enqueues saves) and the history screens.
///
/// History state is separate from GPS state, so a load or save failure never
/// changes tracking or GPS error handling.
@MainActor
final class SessionHistoryModel: ObservableObject {

    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    enum SaveStatus: Equatable {
        case saving
        case saved
        case failed(String)
    }

    /// A completed session whose save has not succeeded yet. The snapshot
    /// keeps its original ID so a retry upserts the same drive.
    struct PendingSave: Identifiable, Equatable {
        let session: CompletedSession
        var status: SaveStatus

        var id: UUID {
            session.id
        }
    }

    // MARK: - Published State

    @Published private(set) var loadState: LoadState = .idle

    /// Sessions confirmed in the archive, newest start first.
    @Published private(set) var savedSessions: [CompletedSession] = []

    /// Saves that are in progress or failed, keyed by session ID.
    @Published private(set) var pendingSaves: [UUID: PendingSave] = [:]

    // MARK: - Dependencies

    private let store: any SessionStoring

    /// Highest store revision already published. A result with a lower
    /// revision is older than the current list and is ignored.
    private var appliedRevision = -1

    private var loadTask: Task<Void, Never>?

    init(store: any SessionStoring) {
        self.store = store
    }

    // MARK: - Derived Values

    /// Pending or failed saves, newest start first.
    var unsavedSessions: [PendingSave] {
        pendingSaves.values.sorted {
            Self.isOrderedBefore($0.session, $1.session)
        }
    }

    func saveStatus(for id: UUID?) -> SaveStatus? {
        guard let id else {
            return nil
        }

        if let pending = pendingSaves[id] {
            return pending.status
        }

        if savedSessions.contains(where: { $0.id == id }) {
            return .saved
        }

        return nil
    }

    // MARK: - Loading

    /// Loads history once, at launch or on first use.
    func loadIfNeeded() async {
        guard loadState == .idle else {
            return
        }

        await reloadHistory()
    }

    /// Loads (or retries loading) the archive.
    func reloadHistory() async {

        if let loadTask {
            await loadTask.value
            return
        }

        let task = Task { [weak self] in
            await self?.performLoad()
        }

        loadTask = task

        await task.value

        loadTask = nil
    }

    private func performLoad() async {

        loadState = .loading

        do {
            let snapshot = try await store.load()
            apply(snapshot)
            loadState = .loaded
        } catch {
            loadState = .failed(Self.message(for: error))
        }
    }

    // MARK: - Saving

    /// Queues a save for a completed session. The caller keeps showing its
    /// own summary while this runs; the snapshot is owned here.
    func enqueueSave(_ session: CompletedSession) {

        if pendingSaves[session.id]?.status == .saving {
            return
        }

        pendingSaves[session.id] = PendingSave(session: session, status: .saving)

        Task { [weak self] in
            await self?.performSave(session)
        }
    }

    /// Retries a failed save of the same drive. Upserting by ID means a
    /// retry can never duplicate the drive or overwrite another one.
    func retrySave(id: UUID) {
        guard let pending = pendingSaves[id],
              pending.status != .saving else {
            return
        }

        enqueueSave(pending.session)
    }

    private func performSave(_ session: CompletedSession) async {

        do {
            let snapshot = try await store.upsert(session)

            pendingSaves[session.id] = nil

            apply(snapshot)

            // A successful write proves the archive is readable, so a
            // previous load failure no longer applies.
            loadState = .loaded

        } catch {
            pendingSaves[session.id] = PendingSave(
                session: session,
                status: .failed(Self.message(for: error))
            )
        }
    }

    // MARK: - Helpers

    private func apply(_ snapshot: SessionArchiveSnapshot) {

        guard snapshot.revision >= appliedRevision else {
            return
        }

        appliedRevision = snapshot.revision

        savedSessions = snapshot.sessions.sorted(by: Self.isOrderedBefore)
    }

    /// Newest start first, with the ID as a stable tie-breaker.
    nonisolated static func isOrderedBefore(
        _ lhs: CompletedSession,
        _ rhs: CompletedSession
    ) -> Bool {
        if lhs.startDate != rhs.startDate {
            return lhs.startDate > rhs.startDate
        }

        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription
            ?? "Drive history is temporarily unavailable."
    }
}
