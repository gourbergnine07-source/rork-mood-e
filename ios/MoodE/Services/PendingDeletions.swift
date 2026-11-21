//
//  PendingDeletions.swift
//  MoodE
//

import Foundation

/// Cloud tables whose deletions are propagated as soft deletes (deleted_at).
nonisolated enum SyncTable: String, CaseIterable, Sendable {
    case library = "library_entries"
    case scheduled = "planner_scheduled"
    case memories = "planner_memories"

    /// Key column used for `.in()` batches.
    var keyColumn: String { self == .library ? "movie_id" : "id" }
}

/// "suppressionsEnAttente": ids the user deleted on this device that still
/// have to be marked `deleted_at` in the cloud. One list per table and per
/// signed-in user, persisted in UserDefaults as { id: deletion date }.
/// An id leaves the list only after its cloud batch succeeded, so offline
/// deletions are retried on the next sync.
nonisolated enum PendingDeletions {
    private static func key(_ table: SyncTable, userId: String) -> String {
        "suppressionsEnAttente.\(table.rawValue).\(userId)"
    }

    static func all(_ table: SyncTable, userId: String) -> [String: Date] {
        let raw = UserDefaults.standard.dictionary(forKey: key(table, userId: userId)) as? [String: Double] ?? [:]
        return raw.mapValues { Date(timeIntervalSince1970: $0) }
    }

    static func add(_ table: SyncTable, ids: [String], userId: String, date: Date = Date()) {
        guard !ids.isEmpty else { return }
        var raw = UserDefaults.standard.dictionary(forKey: key(table, userId: userId)) as? [String: Double] ?? [:]
        for id in ids { raw[id] = date.timeIntervalSince1970 }
        UserDefaults.standard.set(raw, forKey: key(table, userId: userId))
    }

    static func remove(_ table: SyncTable, ids: [String], userId: String) {
        guard !ids.isEmpty else { return }
        var raw = UserDefaults.standard.dictionary(forKey: key(table, userId: userId)) as? [String: Double] ?? [:]
        let before = raw.count
        for id in ids { raw.removeValue(forKey: id) }
        guard raw.count != before else { return }
        UserDefaults.standard.set(raw, forKey: key(table, userId: userId))
    }
}
