//
//  ICloudSyncService.swift
//  MoodE
//

import Foundation
import Observation
import CloudKit

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
        case unavailable
    }

    private(set) var status: Status = .idle
    private(set) var lastSync: Date?

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
        guard PremiumStore.isPremiumCached, !isApplyingRemote else { return }
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
        guard status != .syncing else { return }
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

            if let record = try await Self.fetchRecord() {
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

                isApplyingRemote = true
                diary.replaceAll(mergedCheckIns)
                library.replaceAll(mergedEntries)
                planner.replaceAll(scheduled: mergedScheduled, memories: mergedMemories)
                for month in remoteChallenges {
                    ChallengeStore.shared.markCompleted(month)
                }
                isApplyingRemote = false
            }

            try await pushRecord()
            markSynced()
        } catch {
            isApplyingRemote = false
            print("ICloudSync: sync failed: \(error.localizedDescription)")
            status = .error
        }
    }

    // MARK: - Push only (after local mutations)

    private func push() async {
        guard PremiumStore.isPremiumCached, status != .syncing else { return }
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
            status = .error
        }
    }

    /// Uploads the full local snapshot into the single backup record.
    private func pushRecord() async throws {
        guard let diary, let library, let planner else { return }
        let database = CKContainer.default().privateCloudDatabase
        let recordID = CKRecord.ID(recordName: Self.recordName)

        let record: CKRecord
        if let existing = try await Self.fetchRecord() {
            record = existing
        } else {
            record = CKRecord(recordType: Self.recordType, recordID: recordID)
        }

        let encoder = JSONEncoder()
        record["checkIns"] = try encoder.encode(diary.checkIns) as NSData
        record["entries"] = try encoder.encode(library.entries) as NSData
        record["scheduled"] = try encoder.encode(planner.scheduled) as NSData
        record["memories"] = try encoder.encode(planner.memories) as NSData
        record["challenges"] = Array(ChallengeStore.shared.completedMonths) as NSArray
        record["updatedAt"] = Date() as NSDate

        _ = try await database.save(record)
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
