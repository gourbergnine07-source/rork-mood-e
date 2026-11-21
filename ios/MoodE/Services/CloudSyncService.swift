//
//  CloudSyncService.swift
//  MoodE
//

import Foundation
import Observation
import Supabase

/// Optional cloud backup for the diary, the movie library and the planner.
/// The app stays local-first: when the user signs in, local data is merged
/// with the cloud copy and every later change is pushed automatically
/// (debounced). Signing out never deletes local data.
@Observable
final class CloudSyncService {
    static let shared = CloudSyncService()

    enum Status: Equatable {
        case idle
        case syncing
        case error
    }

    private(set) var status: Status = .idle
    private(set) var lastSync: Date?

    private var auth: AuthManager?
    private var diary: MoodDiary?
    private var library: MovieLibrary?
    private var planner: MoviePlanner?

    /// True while remote data is being applied locally, so the persistence
    /// hooks don't schedule a redundant upload.
    private var isApplyingRemote = false
    private var uploadTask: Task<Void, Never>?

    private static let lastSyncKey = "cloudSync.lastSync"
    /// Rows soft-deleted longer than this are removed for good (daily purge).
    private static let softDeleteRetention: TimeInterval = 60 * 24 * 60 * 60
    /// Soft deletes / restores are sent in `.in()` batches of this size.
    private static let batchSize = 100

    private init() {
        let stored = UserDefaults.standard.double(forKey: Self.lastSyncKey)
        lastSync = stored > 0 ? Date(timeIntervalSince1970: stored) : nil
    }

    /// Wires the shared services once at app start.
    func configure(auth: AuthManager, diary: MoodDiary, library: MovieLibrary, planner: MoviePlanner) {
        self.auth = auth
        self.diary = diary
        self.library = library
        self.planner = planner
    }

    var isSignedIn: Bool { auth?.user != nil }

    // MARK: - Change hook (called from the services' persist paths)

    /// Schedules a debounced upload after any local mutation while signed in.
    func noteLocalChange() {
        guard isSignedIn, !isApplyingRemote else { return }
        uploadTask?.cancel()
        uploadTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            await self?.pushOnly()
        }
    }

    /// Records ids the user just deleted on this device ("suppressionsEnAttente").
    /// They are marked `deleted_at` in the cloud on the next push. No-op when
    /// signed out: without an account there is no cloud copy to update.
    func noteLocalDeletions(_ table: SyncTable, ids: [String]) {
        guard let userId = auth?.user?.id, !ids.isEmpty else { return }
        PendingDeletions.add(table, ids: ids, userId: userId)
        print("CloudSync: queued \(ids.count) deletion(s) for \(table.rawValue)")
    }

    /// A library movie was added again: it must not be soft-deleted anymore.
    func noteLocalRestores(_ table: SyncTable, ids: [String]) {
        guard let userId = auth?.user?.id, !ids.isEmpty else { return }
        PendingDeletions.remove(table, ids: ids, userId: userId)
    }

    /// Cancels pending uploads (e.g. right after sign-out).
    func cancelPendingUpload() {
        uploadTask?.cancel()
        uploadTask = nil
    }

    // MARK: - Full sync (pull + merge + push)

    func syncIfSignedIn() async {
        guard isSignedIn else { return }
        await syncNow()
    }

    /// Two-way sync: downloads the cloud copy, merges it with local data
    /// (union, latest state wins), applies the merge locally, then pushes
    /// the merged state back so the cloud mirrors the device.
    func syncNow() async {
        guard status != .syncing else { return }
        guard let auth, let user = auth.user,
              let diary, let library, let planner else { return }

        status = .syncing
        do {
            await auth.ensureValidToken()
            guard auth.user != nil else {
                status = .error
                return
            }

            let supabase = SupabaseService.client
            let userId = user.id

            try await supabase.from("profiles").upsert(
                ProfileUpsert(id: userId, email: user.email, name: user.name)
            ).execute()

            // Pull
            let remoteCheckIns: [RemoteCheckIn] = try await supabase
                .from("diary_check_ins").select().eq("user_id", value: userId)
                .execute().value
            let remoteEntries: [RemoteLibraryEntry] = try await supabase
                .from("library_entries").select().eq("user_id", value: userId)
                .execute().value
            let remoteScheduled: [RemoteScheduled] = try await supabase
                .from("planner_scheduled").select().eq("user_id", value: userId)
                .execute().value
            let remoteMemories: [RemoteMemory] = try await supabase
                .from("planner_memories").select().eq("user_id", value: userId)
                .execute().value

            // Deletions: drop rows this device deleted (pending) or that
            // another device soft-deleted, before the usual union merge.
            let libraryPrep = Self.prepareLibrary(
                remote: remoteEntries,
                local: library.entries,
                pending: Set(PendingDeletions.all(.library, userId: userId).keys)
            )
            let scheduledPrep = Self.prepareById(
                remote: remoteScheduled.map { ($0.asLocal, $0.deletedAt) },
                local: planner.scheduled,
                pending: Set(PendingDeletions.all(.scheduled, userId: userId).keys),
                key: { $0.id.uuidString }
            )
            let memoriesPrep = Self.prepareById(
                remote: remoteMemories.map { ($0.asLocal, $0.deletedAt) },
                local: planner.memories,
                pending: Set(PendingDeletions.all(.memories, userId: userId).keys),
                key: { $0.id.uuidString }
            )
            print("CloudSync: library ignored(pending)=\(libraryPrep.ignored) removedLocally=\(libraryPrep.removed) toRestore=\(libraryPrep.restore.count)")
            print("CloudSync: planner_scheduled ignored(pending)=\(scheduledPrep.ignored) removedLocally=\(scheduledPrep.removed)")
            print("CloudSync: planner_memories ignored(pending)=\(memoriesPrep.ignored) removedLocally=\(memoriesPrep.removed)")

            // Merge (union by identity; the freshest state wins on conflicts)
            let mergedCheckIns = Self.mergeCheckIns(local: diary.checkIns, remote: remoteCheckIns.map(\.asLocal))
            let mergedEntries = Self.mergeLibrary(local: libraryPrep.local, remote: libraryPrep.remote)
            let mergedScheduled = Self.mergeById(local: scheduledPrep.local, remote: scheduledPrep.remote)
            let mergedMemories = Self.mergeById(local: memoriesPrep.local, remote: memoriesPrep.remote)

            // Apply locally without re-triggering the upload hook
            isApplyingRemote = true
            diary.replaceAll(mergedCheckIns)
            library.replaceAll(mergedEntries)
            planner.replaceAll(scheduled: mergedScheduled, memories: mergedMemories)
            // Auto-removals done at launch (before sign-in was known) are
            // recorded now, so they become soft deletes too.
            library.pruneExpiredWatched()
            isApplyingRemote = false

            try await pushAllRows(userId: userId, libraryRestores: libraryPrep.restore)
            await purgeExpiredDeletionsIfNeeded(userId: userId)

            markSynced()
        } catch {
            isApplyingRemote = false
            print("CloudSync: sync failed: \(error.localizedDescription)")
            status = .error
        }
    }

    // MARK: - Push only (after local mutations)

    private func pushOnly() async {
        guard status != .syncing else { return }
        guard let auth, let user = auth.user else { return }
        status = .syncing
        do {
            await auth.ensureValidToken()
            guard auth.user != nil else {
                status = .error
                return
            }
            try await pushAllRows(userId: user.id)
            markSynced()
        } catch {
            print("CloudSync: push failed: \(error.localizedDescription)")
            status = .error
        }
    }

    /// Upserts the full local state, then marks the ids the user deleted on
    /// this device ("suppressionsEnAttente") with `deleted_at`. Rows are never
    /// pruned by "missing locally" anymore: a device that simply hasn't seen
    /// a row yet can no longer erase it from the cloud.
    private func pushAllRows(userId: String, libraryRestores: [String] = []) async throws {
        guard let diary, let library, let planner else { return }
        let supabase = SupabaseService.client

        let checkIns = diary.checkIns
        if !checkIns.isEmpty {
            try await supabase.from("diary_check_ins")
                .upsert(checkIns.map { RemoteCheckIn(from: $0, userId: userId) })
                .execute()
        }
        // No deleteMissing for diary_check_ins: the app never deletes a single
        // check-in (only full account deletion does), so pruning here would
        // wipe check-ins created on the user's other devices.

        let entries = library.entries
        if !entries.isEmpty {
            try await supabase.from("library_entries")
                .upsert(entries.map { RemoteLibraryEntry(from: $0, userId: userId) })
                .execute()
        }
        var deletionError: Error?
        if !libraryRestores.isEmpty {
            do {
                try await updateDeletedAt(.library, ids: libraryRestores, value: nil, userId: userId)
                print("CloudSync: library restored \(libraryRestores.count) row(s) (deleted_at cleared)")
            } catch {
                print("CloudSync: library restore failed: \(error.localizedDescription)")
                deletionError = error
            }
        }
        do { try await softDeletePending(.library, userId: userId) } catch { deletionError = error }

        let scheduled = planner.scheduled
        if !scheduled.isEmpty {
            try await supabase.from("planner_scheduled")
                .upsert(scheduled.map { RemoteScheduled(from: $0, userId: userId) })
                .execute()
        }
        do { try await softDeletePending(.scheduled, userId: userId) } catch { deletionError = error }

        let memories = planner.memories
        if !memories.isEmpty {
            try await supabase.from("planner_memories")
                .upsert(memories.map { RemoteMemory(from: $0, userId: userId) })
                .execute()
        }
        do { try await softDeletePending(.memories, userId: userId) } catch { deletionError = error }

        // Failed batches stay in the pending list and are retried next sync.
        if let deletionError { throw deletionError }
    }

    // MARK: - Soft delete (deleted_at)

    /// Marks every pending id of `table` as deleted (`deleted_at = now`),
    /// in batches. Only the ids of successful batches leave the list.
    private func softDeletePending(_ table: SyncTable, userId: String) async throws {
        let ids = Array(PendingDeletions.all(table, userId: userId).keys)
        guard !ids.isEmpty else { return }
        let now = ISO8601DateFormatter().string(from: Date())
        var done = 0
        var lastError: Error?
        for start in stride(from: 0, to: ids.count, by: Self.batchSize) {
            let batch = Array(ids[start..<min(start + Self.batchSize, ids.count)])
            do {
                try await updateDeletedAt(table, ids: batch, value: now, userId: userId)
                PendingDeletions.remove(table, ids: batch, userId: userId)
                done += batch.count
            } catch {
                print("CloudSync: soft delete batch failed for \(table.rawValue): \(error.localizedDescription)")
                lastError = error
            }
        }
        print("CloudSync: \(table.rawValue) soft-deleted \(done)/\(ids.count), still pending \(ids.count - done)")
        if let lastError { throw lastError }
    }

    /// Sets (ISO date) or clears (nil) `deleted_at` on the given ids,
    /// in `.in()` batches of 100.
    private func updateDeletedAt(_ table: SyncTable, ids: [String], value: String?, userId: String) async throws {
        let supabase = SupabaseService.client
        for start in stride(from: 0, to: ids.count, by: Self.batchSize) {
            let batch = Array(ids[start..<min(start + Self.batchSize, ids.count)])
            try await supabase.from(table.rawValue)
                .update(DeletedAtPatch(deletedAt: value))
                .eq("user_id", value: userId)
                .in(table.keyColumn, values: batch)
                .execute()
        }
    }

    /// Once a day, permanently removes the user's rows soft-deleted more
    /// than 60 days ago (date filter, never a list of ids). Non-blocking.
    private func purgeExpiredDeletionsIfNeeded(userId: String) async {
        let key = "cloudSync.lastPurge.\(userId)"
        let last = UserDefaults.standard.double(forKey: key)
        guard Date().timeIntervalSince1970 - last >= 24 * 60 * 60 else { return }
        let cutoff = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-Self.softDeleteRetention))
        let supabase = SupabaseService.client
        var succeeded = true
        for table in SyncTable.allCases {
            do {
                try await supabase.from(table.rawValue)
                    .delete()
                    .eq("user_id", value: userId)
                    .lt("deleted_at", value: cutoff)
                    .execute()
            } catch {
                succeeded = false
                print("CloudSync: purge failed for \(table.rawValue): \(error.localizedDescription)")
            }
        }
        if succeeded {
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: key)
            print("CloudSync: purge done (deleted_at < \(cutoff))")
        }
    }

    // MARK: - Deletion-aware pre-merge

    /// Library rows are keyed by movie id, which can be added again later.
    /// A soft-deleted row is dropped (and removed locally) only when neither
    /// copy has activity newer than `deleted_at`; otherwise it was re-added
    /// after the deletion, so it stays and `deleted_at` is cleared.
    private static func prepareLibrary(
        remote: [RemoteLibraryEntry],
        local: [LibraryEntry],
        pending: Set<String>
    ) -> (remote: [LibraryEntry], local: [LibraryEntry], restore: [String], ignored: Int, removed: Int) {
        func activity(_ entry: LibraryEntry) -> Date {
            max(entry.addedDate, entry.watchedDate ?? .distantPast)
        }
        var localById: [Int: LibraryEntry] = [:]
        for entry in local { localById[entry.id] = entry }

        var keptRemote: [LibraryEntry] = []
        var removeLocally = Set<Int>()
        var restore: [String] = []
        var ignored = 0
        for row in remote {
            guard let entry = row.asLocal else { continue }
            let key = String(entry.id)
            if pending.contains(key) { ignored += 1; continue }
            guard let deletedAt = row.deletedAt else {
                keptRemote.append(entry)
                continue
            }
            let remoteAlive = activity(entry) > deletedAt
            let localAlive = localById[entry.id].map { activity($0) > deletedAt } ?? false
            if remoteAlive || localAlive {
                if remoteAlive { keptRemote.append(entry) }
                restore.append(key)
            } else {
                removeLocally.insert(entry.id)
            }
        }
        let keptLocal = local.filter { !removeLocally.contains($0.id) && !pending.contains(String($0.id)) }
        return (keptRemote, keptLocal, restore, ignored, local.count - keptLocal.count)
    }

    /// Planner rows use fresh UUIDs, so a soft-deleted id is gone for good:
    /// it is removed locally and never sent back. Local rows the cloud has
    /// never seen are kept (and uploaded), never deleted.
    private static func prepareById<T: Identifiable>(
        remote: [(T, Date?)],
        local: [T],
        pending: Set<String>,
        key: (T) -> String
    ) -> (remote: [T], local: [T], ignored: Int, removed: Int) {
        var keptRemote: [T] = []
        var deletedKeys = Set<String>()
        var ignored = 0
        for (item, deletedAt) in remote {
            let itemKey = key(item)
            if pending.contains(itemKey) { ignored += 1; continue }
            if deletedAt != nil { deletedKeys.insert(itemKey); continue }
            keptRemote.append(item)
        }
        let keptLocal = local.filter {
            let itemKey = key($0)
            return !deletedKeys.contains(itemKey) && !pending.contains(itemKey)
        }
        return (keptRemote, keptLocal, ignored, local.count - keptLocal.count)
    }

    // MARK: - Account deletion (App Store guideline 5.1.1(v))

    /// Permanently deletes every cloud row belonging to the signed-in user
    /// (diary, library, planner and profile). Local data is untouched.
    /// The caller signs the user out afterwards.
    func deleteAccountData() async throws {
        guard let auth, let user = auth.user else { return }
        cancelPendingUpload()

        await auth.ensureValidToken()
        guard auth.user != nil else {
            throw URLError(.userAuthenticationRequired)
        }

        let supabase = SupabaseService.client
        let userId = user.id

        for table in ["diary_check_ins", "library_entries", "planner_scheduled", "planner_memories", "friend_stats"] {
            try await supabase.from(table)
                .delete()
                .eq("user_id", value: userId)
                .execute()
        }
        // Friend links reference the user from either side.
        try await supabase.from("friends")
            .delete()
            .or("user_id.eq.\(userId),friend_id.eq.\(userId)")
            .execute()
        try await supabase.from("profiles")
            .delete()
            .eq("id", value: userId)
            .execute()

        lastSync = nil
        UserDefaults.standard.removeObject(forKey: Self.lastSyncKey)
        status = .idle
    }

    private func markSynced() {
        lastSync = Date()
        UserDefaults.standard.set(lastSync?.timeIntervalSince1970 ?? 0, forKey: Self.lastSyncKey)
        status = .idle
    }

    // MARK: - Merge helpers (shared with ICloudSyncService)

    /// `{ "deleted_at": <ISO date> | null }`, with an explicit null so a
    /// restore really clears the column.
    private nonisolated struct DeletedAtPatch: Encodable, Sendable {
        let deletedAt: String?

        enum CodingKeys: String, CodingKey { case deletedAt = "deleted_at" }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            if let deletedAt {
                try container.encode(deletedAt, forKey: .deletedAt)
            } else {
                try container.encodeNil(forKey: .deletedAt)
            }
        }
    }

    static func mergeCheckIns(local: [MoodCheckIn], remote: [MoodCheckIn]) -> [MoodCheckIn] {
        var byId: [UUID: MoodCheckIn] = [:]
        for checkIn in remote { byId[checkIn.id] = checkIn }
        // Local wins on id conflicts (it may carry fresher notes).
        for checkIn in local { byId[checkIn.id] = checkIn }
        return byId.values.sorted { $0.date > $1.date }
    }

    static func mergeLibrary(local: [LibraryEntry], remote: [LibraryEntry]) -> [LibraryEntry] {
        func activity(_ entry: LibraryEntry) -> Date {
            max(entry.addedDate, entry.watchedDate ?? .distantPast)
        }
        var byMovie: [Int: LibraryEntry] = [:]
        for entry in remote { byMovie[entry.id] = entry }
        for entry in local {
            if let existing = byMovie[entry.id], activity(existing) > activity(entry) {
                continue
            }
            byMovie[entry.id] = entry
        }
        return byMovie.values.sorted { $0.addedDate > $1.addedDate }
    }

    static func mergeById<T: Identifiable>(local: [T], remote: [T]) -> [T] where T.ID: Hashable {
        var byId: [T.ID: T] = [:]
        for item in remote { byId[item.id] = item }
        for item in local { byId[item.id] = item }
        return Array(byId.values)
    }
}
