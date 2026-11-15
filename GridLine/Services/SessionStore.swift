//
//  SessionStore.swift
//  GridLine
//
//  Created by Kenton & Ethan.
//

import Foundation

/// Archive contents returned by a store operation.
///
/// `revision` increases after every successful write performed by a store
/// instance. The history model uses it to ignore results that are older than
/// what it has already published (for example, a slow launch load finishing
/// after a newer save).
nonisolated struct SessionArchiveSnapshot: Sendable {
    let revision: Int
    let sessions: [CompletedSession]
}

/// Recoverable persistence failures shown in the history UI.
nonisolated enum SessionStoreError: LocalizedError, Equatable, Sendable {

    /// The archive exists but could not be read or decoded. Its bytes are
    /// left untouched.
    case unreadableArchive

    /// The archive was written by an unsupported (for example, newer) format.
    case unsupportedVersion(Int)

    /// The archive could not be written. The last saved archive is kept.
    case writeFailed

    var errorDescription: String? {
        switch self {

        case .unreadableArchive:
            return "Saved drive history could not be read. It has been left unchanged on this device."

        case .unsupportedVersion(let version):
            return "Saved drive history uses an unsupported format (version \(version)). It has been left unchanged on this device."

        case .writeFailed:
            return "The drive could not be saved to this device. Previously saved drives are unchanged."
        }
    }
}

/// Storage for completed sessions. Implementations serialize every
/// read-modify-write and perform disk and encoding work off the main actor.
nonisolated protocol SessionStoring: Sendable {

    /// Reads the full archive. A missing archive is an empty history.
    func load() async throws -> SessionArchiveSnapshot

    /// Inserts the session, or replaces the stored session with the same ID,
    /// while preserving every other stored session.
    func upsert(_ session: CompletedSession) async throws -> SessionArchiveSnapshot
}

// MARK: - File Store

/// Versioned Codable JSON archive in an app-owned Application Support
/// directory. The directory is excluded from backups so drive data stays on
/// the device. Writes are atomic, so a failed write never replaces the last
/// successfully saved archive.
actor FileSessionStore: SessionStoring {

    static let currentVersion = 1

    private nonisolated struct Archive: Codable, Sendable {
        let version: Int
        let sessions: [CompletedSession]
    }

    /// Decoded first so an unsupported version can be reported separately
    /// from damaged data.
    private nonisolated struct VersionHeader: Decodable, Sendable {
        let version: Int
    }

    let directoryURL: URL

    private var revision = 0

    private var archiveURL: URL {
        directoryURL.appendingPathComponent("sessions.json", isDirectory: false)
    }

    init(directoryURL: URL) {
        self.directoryURL = directoryURL
    }

    /// Production location: `Application Support/SessionHistory/`.
    static func applicationSupport() -> FileSessionStore {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory

        return FileSessionStore(
            directoryURL: base.appendingPathComponent("SessionHistory", isDirectory: true)
        )
    }

    // MARK: - SessionStoring

    func load() async throws -> SessionArchiveSnapshot {
        let sessions = try readSessions()
        return SessionArchiveSnapshot(revision: revision, sessions: sessions)
    }

    func upsert(_ session: CompletedSession) async throws -> SessionArchiveSnapshot {

        // Reading first means an unreadable or unsupported archive throws
        // here, before anything is written, so its bytes are preserved.
        var sessions = try readSessions()

        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }

        try write(sessions)

        revision += 1

        return SessionArchiveSnapshot(revision: revision, sessions: sessions)
    }

    // MARK: - Disk

    private func readSessions() throws -> [CompletedSession] {

        let data: Data

        do {
            data = try Data(contentsOf: archiveURL)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return []
        } catch {
            if !FileManager.default.fileExists(atPath: archiveURL.path) {
                return []
            }

            throw SessionStoreError.unreadableArchive
        }

        let decoder = JSONDecoder()

        guard let header = try? decoder.decode(VersionHeader.self, from: data) else {
            throw SessionStoreError.unreadableArchive
        }

        guard header.version == Self.currentVersion else {
            throw SessionStoreError.unsupportedVersion(header.version)
        }

        do {
            return try decoder.decode(Archive.self, from: data).sessions
        } catch {
            throw SessionStoreError.unreadableArchive
        }
    }

    private func write(_ sessions: [CompletedSession]) throws {

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        do {
            let data = try encoder.encode(
                Archive(version: Self.currentVersion, sessions: sessions)
            )

            try prepareDirectory()

            try data.write(to: archiveURL, options: [.atomic])
        } catch {
            throw SessionStoreError.writeFailed
        }
    }

    /// Creates the app-owned directory as needed and keeps it out of backups.
    private func prepareDirectory() throws {

        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        var values = URLResourceValues()
        values.isExcludedFromBackup = true

        var url = directoryURL
        try url.setResourceValues(values)
    }
}

// MARK: - In-Memory Store

/// Isolated store for previews and scripted UI-test drives, so those drives
/// never reach real history on the device.
actor InMemorySessionStore: SessionStoring {

    private var sessions: [CompletedSession]
    private var revision = 0

    init(sessions: [CompletedSession] = []) {
        self.sessions = sessions
    }

    func load() async throws -> SessionArchiveSnapshot {
        SessionArchiveSnapshot(revision: revision, sessions: sessions)
    }

    func upsert(_ session: CompletedSession) async throws -> SessionArchiveSnapshot {

        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }

        revision += 1

        return SessionArchiveSnapshot(revision: revision, sessions: sessions)
    }
}
