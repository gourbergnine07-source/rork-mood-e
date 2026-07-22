//
//  ICloudSyncService.swift
//  MoodE
//

import Foundation
import Observation
import CloudKit
import CryptoKit

/// Premium-only iCloud sync (CloudKit private database): the diary, the
/// movie library, the planner and the completed challenges are stored as a
/// single record tied to the device's iCloud account, so data stays
/// consistent across the user's Apple devices. Free users keep local-only
/// storage — this service is a no-op for them.
@Observable
final class ICloudSyncService {
    static let shared = ICloudSyncService()

    enum Status: Equatable {
        case idle
        case syncing
        case error
        /// No internet connection: sync will retry automatically later.
        case offline
        case unavailable
        /// A merge conflict was detected and awaits the user's decision.
        case conflict
    }

    /// Detected when the same items were edited on two devices: the merge
    /// is held back until the user confirms via the in-app alert.
    struct MergeConflict: Equatable {
        let itemCount: Int
    }

    /// Merged data computed for a conflicting sync, kept aside until the
    /// user chooses how to proceed.
    private struct PendingMerge {
        let checkIns: [MoodCheckIn]
        let entries: [LibraryEntry]
        let scheduled: [ScheduledMovie]
        let memories: [MovieMemory]
        let challenges: [String]
        let remoteUpdated: Double?
    }

    private(set) var status: Status = .idle
    private(set) var lastSync: Date?
    private(set) var conflict: MergeConflict?
    /// Incremented ONLY when a full sync completes successfully with no
    /// merge conflict detected: the UI observes it to show a discreet
    /// confirmation toast. Background debounced pushes don't touch it.
    private(set) var successSignal: Int = 0
    private var pendingMerge: PendingMerge?

    private var diary: MoodDiary?
    private var library: MovieLibrary?
    private var planner: MoviePlanner?

    /// True while remote data is being applied locally, so the persistence
    /// hooks don't schedule a redundant upload.
    private var isApplyingRemote = false
    private var uploadTask: Task<Void, Never>?

    private static let lastSyncKey = "icloud.lastSync"
    private static let recordType = "MoodEBackup"
    private static let recordName = "moode-premium-backup"
    /// SHA256 fingerprints of the sections uploaded in the last successful
    /// push, so subsequent backups only transfer what actually changed.
    private static let pushedHashesKey = "icloud.pushedHashes"
    /// `updatedAt` of the last cloud copy already merged on this device,
    /// so unchanged backups are not re-downloaded on every manual sync.
    private static let remoteUpdatedKey = "icloud.remoteUpdatedAt"

    private init() {
        let stored = UserDefaults.standard.double(forKey: Self.lastSyncKey)
        lastSync = stored > 0 ? Date(timeIntervalSince1970: stored) : nil
    }

    /// Wires the shared services once at app start.
    func configure(diary: MoodDiary, library: MovieLibrary, planner: MoviePlanner) {
        self.diary = diary
        self.library = library
        self.planner = planner
    }

    // MARK: - Change hook (called from the services' persist paths)

    /// True when the device is signed into iCloud. Checked BEFORE any
    /// CloudKit call: touching CKContainer without an iCloud account (e.g.
    /// in the cloud preview simulator) can raise an uncatchable exception
    /// and terminate the app. This check is always safe to call.
    nonisolated private static var hasICloudAccount: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    /// Schedules a debounced upload after any local mutation, Premium only.
    func noteLocalChange() {
        guard PremiumStore.isPremiumCached, !isApplyingRemote, conflict == nil else { return }
        guard Self.hasICloudAccount else {
            status = .unavailable
            return
        }
        uploadTask?.cancel()
        uploadTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            await self?.push()
        }
    }

    // MARK: - Full sync (pull + merge + push)

    /// Two-way sync: downloads the iCloud copy, merges it with local data
    /// (union, freshest state wins), applies the merge locally, then pushes
    /// the merged state back. No-op for free users.
    func syncIfPremium() async {
        guard PremiumStore.isPremiumCached else { return }
        guard status != .syncing, conflict == nil else { return }
        guard let diary, let library, let planner else { return }
        guard Self.hasICloudAccount else {
            status = .unavailable
            return
        }

        status = .syncing
        do {
            guard try await Self.accountAvailable() else {
                status = .unavailable
                return
            }

            // Incremental pull: a cheap metadata-only fetch first; the full
            // backup is downloaded only when the cloud copy is newer than
            // the one already merged on this device.
            let storedRemote = UserDefaults.standard.double(forKey: Self.remoteUpdatedKey)
            let stub = try await Self.fetchRecordStub()
            let remoteUpdated = (stub?["updatedAt"] as? Date)?.timeIntervalSince1970
            let needsPull = stub != nil && (remoteUpdated == nil || remoteUpdated! > storedRemote)

            if needsPull, let record = try await Self.fetchRecord() {
                let decoder = JSONDecoder()
                let remoteCheckIns: [MoodCheckIn] = Self.decode(record["checkIns"], decoder) ?? []
                let remoteEntries: [LibraryEntry] = Self.decode(record["entries"], decoder) ?? []
                let remoteScheduled: [ScheduledMovie] = Self.decode(record["scheduled"], decoder) ?? []
                let remoteMemories: [MovieMemory] = Self.decode(record["memories"], decoder) ?? []
                let remoteChallenges = (record["challenges"] as? [String]) ?? []

                let mergedCheckIns = CloudSyncService.mergeCheckIns(local: diary.checkIns, remote: remoteCheckIns)
                let mergedEntries = CloudSyncService.mergeLibrary(local: library.entries, remote: remoteEntries)
                let mergedScheduled = CloudSyncService.mergeById(local: planner.scheduled, remote: remoteScheduled)
                let mergedMemories = CloudSyncService.mergeById(local: planner.memories, remote: remoteMemories)

                // Conflict gate: when the same items were modified on both
                // devices, hold the merge and ask the user before anything
                // gets overwritten.
                let conflictCount = Self.conflictCount(local: diary.checkIns, remote: remoteCheckIns)
                    + Self.conflictCount(local: library.entries, remote: remoteEntries)
                    + Self.conflictCount(local: planner.scheduled, remote: remoteScheduled)
                    + Self.conflictCount(local: planner.memories, remote: remoteMemories)

                if conflictCount > 0 {
                    pendingMerge = PendingMerge(
                        checkIns: mergedCheckIns,
                        entries: mergedEntries,
                        scheduled: mergedScheduled,
                        memories: mergedMemories,
                        challenges: remoteChallenges,
                        remoteUpdated: remoteUpdated
                    )
                    conflict = MergeConflict(itemCount: conflictCount)
                    status = .conflict
                    print("ICloudSync: merge conflict on \(conflictCount) item(s), waiting for user decision")
                    return
                }

                isApplyingRemote = true
                diary.replaceAll(mergedCheckIns)
                library.replaceAll(mergedEntries)
                planner.replaceAll(scheduled: mergedScheduled, memories: mergedMemories)
                for month in remoteChallenges {
                    ChallengeStore.shared.markCompleted(month)
                }
                isApplyingRemote = false
                UserDefaults.standard.set(remoteUpdated ?? Date().timeIntervalSince1970, forKey: Self.remoteUpdatedKey)
            }

            try await pushRecord()
            markSynced()
            successSignal += 1
        } catch {
            isApplyingRemote = false
            print("ICloudSync: sync failed: \(error.localizedDescription)")
            status = Self.isNetworkError(error) ? .offline : .error
        }
    }

    // MARK: - Conflict resolution

    /// Applies the user's decision on a detected merge conflict.
    /// - `applyMerge == true`: applies the merged data locally (the most
    ///   recent version of each item wins) and uploads the result.
    /// - `applyMerge == false`: keeps this device's data untouched and
    ///   replaces the cloud copy with it on the next upload.
    func resolveConflict(applyMerge: Bool) async {
        guard let pending = pendingMerge else {
            conflict = nil
            if status == .conflict { status = .idle }
            return
        }
        pendingMerge = nil
        conflict = nil
        status = .idle

        if applyMerge, let diary, let library, let planner {
            isApplyingRemote = true
            diary.replaceAll(pending.checkIns)
            library.replaceAll(pending.entries)
            planner.replaceAll(scheduled: pending.scheduled, memories: pending.memories)
            for month in pending.challenges {
                ChallengeStore.shared.markCompleted(month)
            }
            isApplyingRemote = false
        } else {
            // Force the next upload to send every section, so this device's
            // data fully replaces the cloud copy.
            UserDefaults.standard.removeObject(forKey: Self.pushedHashesKey)
        }
        UserDefaults.standard.set(pending.remoteUpdated ?? Date().timeIntervalSince1970, forKey: Self.remoteUpdatedKey)
        await push()
    }

    /// Number of items present on both sides (same identity) whose content
    /// differs — i.e. items the merge would overwrite on one of the devices.
    nonisolated private static func conflictCount<T: Identifiable & Encodable>(local: [T], remote: [T]) -> Int where T.ID: Hashable {
        guard !local.isEmpty, !remote.isEmpty else { return 0 }
        let encoder = JSONEncoder()
        var remoteById: [T.ID: T] = [:]
        for item in remote { remoteById[item.id] = item }
        var count = 0
        for item in local {
            guard let other = remoteById[item.id] else { continue }
            if (try? encoder.encode(item)) != (try? encoder.encode(other)) {
                count += 1
            }
        }
        return count
    }

    // MARK: - Push only (after local mutations)

    private func push() async {
        guard PremiumStore.isPremiumCached, status != .syncing, conflict == nil else { return }
        guard Self.hasICloudAccount else {
            status = .unavailable
            return
        }
        status = .syncing
        do {
            guard try await Self.accountAvailable() else {
                status = .unavailable
                return
            }
            try await pushRecord()
            markSynced()
        } catch {
            print("ICloudSync: push failed: \(error.localizedDescription)")
            status = Self.isNetworkError(error) ? .offline : .error
        }
    }

    /// True when the failure comes from a missing or broken internet
    /// connection, so the UI can show a dedicated "offline" message
    /// instead of a generic error.
    nonisolated private static func isNetworkError(_ error: Error) -> Bool {
        if let ckError = error as? CKError {
            switch ckError.code {
            case .networkUnavailable, .networkFailure:
                return true
            default:
                // Batch operations wrap per-item failures.
                if let partial = ckError.partialErrorsByItemID?.values
                    .compactMap({ $0 as? CKError })
                    .first(where: { $0.code == .networkUnavailable || $0.code == .networkFailure }) {
                    _ = partial
                    return true
                }
                return false
            }
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut,
                 .cannotFindHost, .cannotConnectToHost, .dataNotAllowed:
                return true
            default:
                return false
            }
        }
        return false
    }

    /// Incremental backup: encodes each section, compares it with the
    /// fingerprint of the last successful upload and sends ONLY the fields
    /// that changed. When nothing changed the network call is skipped
    /// entirely, keeping manual syncs light on data.
    private func pushRecord() async throws {
        guard let diary, let library, let planner else { return }
        let database = CKContainer.default().privateCloudDatabase

        let encoder = JSONEncoder()
        let challenges = Array(ChallengeStore.shared.completedMonths).sorted()
        let payloads: [String: Data] = [
            "checkIns": try encoder.encode(diary.checkIns),
            "entries": try encoder.encode(library.entries),
            "scheduled": try encoder.encode(planner.scheduled),
            "memories": try encoder.encode(planner.memories),
            "challenges": try encoder.encode(challenges),
        ]
        let hashes = payloads.mapValues { Self.hash($0) }
        let stored = (UserDefaults.standard.dictionary(forKey: Self.pushedHashesKey) as? [String: String]) ?? [:]

        // Metadata-only fetch (no data payloads) to know whether the
        // backup record exists and to carry its change tag for the save.
        let existing = try await Self.fetchRecordStub()

        let changedKeys: Set<String>
        if existing == nil {
            changedKeys = Set(payloads.keys) // first backup: upload everything
        } else {
            changedKeys = Set(hashes.filter { stored[$0.key] != $0.value }.map(\.key))
        }

        guard !changedKeys.isEmpty else {
            print("ICloudSync: no local changes, upload skipped")
            return
        }
        print("ICloudSync: incremental push of \(changedKeys.sorted().joined(separator: ", "))")

        let record = existing ?? CKRecord(recordType: Self.recordType, recordID: CKRecord.ID(recordName: Self.recordName))
        Self.apply(payloads: payloads, keys: changedKeys, challenges: challenges, to: record)

        do {
            let saved = try await database.save(record)
            Self.storePushState(hashes: hashes, savedRecord: saved)
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Another device updated the backup meanwhile: re-apply our
            // changed sections on top of the fresh server copy, retry once.
            guard let server = error.serverRecord else { throw error }
            Self.apply(payloads: payloads, keys: changedKeys, challenges: challenges, to: server)
            let saved = try await database.save(server)
            Self.storePushState(hashes: hashes, savedRecord: saved)
        }
    }

    /// Writes the given sections into the record. Challenges keep their
    /// legacy `[String]` format; the encoded Data is only used for hashing.
    nonisolated private static func apply(payloads: [String: Data], keys: Set<String>, challenges: [String], to record: CKRecord) {
        for key in keys {
            if key == "challenges" {
                record["challenges"] = challenges as NSArray
            } else if let data = payloads[key] {
                record[key] = data as NSData
            }
        }
        record["updatedAt"] = Date() as NSDate
    }

    /// Remembers what was uploaded so the next push can diff against it.
    nonisolated private static func storePushState(hashes: [String: String], savedRecord: CKRecord) {
        UserDefaults.standard.set(hashes, forKey: pushedHashesKey)
        let updated = (savedRecord["updatedAt"] as? Date)?.timeIntervalSince1970 ?? Date().timeIntervalSince1970
        UserDefaults.standard.set(updated, forKey: remoteUpdatedKey)
    }

    nonisolated private static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - CloudKit helpers

    private static func accountAvailable() async throws -> Bool {
        try await CKContainer.default().accountStatus() == .available
    }

    /// Returns the backup record, or nil when none exists yet.
    private static func fetchRecord() async throws -> CKRecord? {
        let database = CKContainer.default().privateCloudDatabase
        do {
            return try await database.record(for: CKRecord.ID(recordName: recordName))
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    /// Metadata-only fetch: retrieves just `updatedAt` (no data payloads),
    /// so existence/staleness checks cost a few bytes instead of the full
    /// backup download.
    private static func fetchRecordStub() async throws -> CKRecord? {
        let database = CKContainer.default().privateCloudDatabase
        let id = CKRecord.ID(recordName: recordName)
        do {
            let results = try await database.records(for: [id], desiredKeys: ["updatedAt"])
            return try results[id]?.get()
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    private static func decode<T: Decodable>(_ value: Any?, _ decoder: JSONDecoder) -> T? {
        guard let data = value as? Data else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    private func markSynced() {
        lastSync = Date()
        UserDefaults.standard.set(lastSync?.timeIntervalSince1970 ?? 0, forKey: Self.lastSyncKey)
        status = .idle
    }
}
