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

            // Merge (union by identity; the freshest state wins on conflicts)
            let mergedCheckIns = Self.mergeCheckIns(local: diary.checkIns, remote: remoteCheckIns.map(\.asLocal))
            let mergedEntries = Self.mergeLibrary(local: library.entries, remote: remoteEntries.compactMap(\.asLocal))
            let mergedScheduled = Self.mergeById(local: planner.scheduled, remote: remoteScheduled.map(\.asLocal))
            let mergedMemories = Self.mergeById(local: planner.memories, remote: remoteMemories.map(\.asLocal))

            // Apply locally without re-triggering the upload hook
            isApplyingRemote = true
            diary.replaceAll(mergedCheckIns)
            library.replaceAll(mergedEntries)
            planner.replaceAll(scheduled: mergedScheduled, memories: mergedMemories)
            isApplyingRemote = false

            try await pushAllRows(userId: userId)

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

    /// Upserts the full local state and prunes remote rows that no longer
    /// exist locally, so deletions propagate to the cloud.
    private func pushAllRows(userId: String) async throws {
        guard let diary, let library, let planner else { return }
        let supabase = SupabaseService.client

        let checkIns = diary.checkIns
        if !checkIns.isEmpty {
            try await supabase.from("diary_check_ins")
                .upsert(checkIns.map { RemoteCheckIn(from: $0, userId: userId) })
                .execute()
        }
        try await deleteMissing(
            table: "diary_check_ins", column: "id",
            keep: checkIns.map { $0.id.uuidString }, userId: userId
        )

        let entries = library.entries
        if !entries.isEmpty {
            try await supabase.from("library_entries")
                .upsert(entries.map { RemoteLibraryEntry(from: $0, userId: userId) })
                .execute()
        }
        try await deleteMissing(
            table: "library_entries", column: "movie_id",
            keep: entries.map { String($0.id) }, userId: userId, quoted: false
        )

        let scheduled = planner.scheduled
        if !scheduled.isEmpty {
            try await supabase.from("planner_scheduled")
                .upsert(scheduled.map { RemoteScheduled(from: $0, userId: userId) })
                .execute()
        }
        try await deleteMissing(
            table: "planner_scheduled", column: "id",
            keep: scheduled.map { $0.id.uuidString }, userId: userId
        )

        let memories = planner.memories
        if !memories.isEmpty {
            try await supabase.from("planner_memories")
                .upsert(memories.map { RemoteMemory(from: $0, userId: userId) })
                .execute()
        }
        try await deleteMissing(
            table: "planner_memories", column: "id",
            keep: memories.map { $0.id.uuidString }, userId: userId
        )
    }

    /// Deletes the user's remote rows whose key is not in `keep`.
    private func deleteMissing(
        table: String,
        column: String,
        keep: [String],
        userId: String,
        quoted: Bool = true
    ) async throws {
        let supabase = SupabaseService.client
        if keep.isEmpty {
            try await supabase.from(table)
                .delete()
                .eq("user_id", value: userId)
                .execute()
            return
        }
        let list = "(" + keep.map { quoted ? "\"\($0)\"" : $0 }.joined(separator: ",") + ")"
        try await supabase.from(table)
            .delete()
            .eq("user_id", value: userId)
            .not(column, operator: .in, value: list)
            .execute()
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
