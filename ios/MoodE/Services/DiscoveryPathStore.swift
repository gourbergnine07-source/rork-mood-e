//
//  DiscoveryPathStore.swift
//  MoodE
//

import Foundation
import Observation

/// Remembers, per movie, the mood → goal → era combination that led the user
/// to save it from the results screen.
///
/// The path also travels inside `LibraryEntry`, so it rides along with the
/// iCloud backup for Premium users; this store is the single read surface
/// used by the UI and it keeps the information alive even when the library
/// entry is gone (auto-removal after a week) while the movie still lives in
/// "I miei ricordi cinematografici".
@Observable
final class DiscoveryPathStore {
    static let shared = DiscoveryPathStore()

    /// Paths keyed by TMDB movie id.
    private(set) var paths: [Int: DiscoveryPath]

    private static let key = "discovery.paths"
    private let defaults = UserDefaults.standard

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let stored = try? JSONDecoder().decode([String: DiscoveryPath].self, from: data) {
            paths = Dictionary(
                uniqueKeysWithValues: stored.compactMap { key, value in
                    Int(key).map { ($0, value) }
                }
            )
        } else {
            paths = [:]
        }
    }

    // MARK: - Queries

    /// The discovery path of a movie, or nil when it was added from another
    /// source (manual search, Tendenze, poster scan) — callers then show
    /// nothing at all.
    func path(for movieId: Int) -> DiscoveryPath? {
        paths[movieId]
    }

    // MARK: - Mutations

    /// Records the flow combination used to reach a movie. Saving the same
    /// movie again through a different mood keeps the most recent path.
    func record(_ path: DiscoveryPath, for movieId: Int) {
        if let existing = paths[movieId], existing.savedDate >= path.savedDate { return }
        paths[movieId] = path
        persist()
    }

    /// Merges the paths carried by library entries (fresh install restored
    /// from iCloud, or a sync that brought entries from another device).
    func hydrate(from entries: [LibraryEntry]) {
        var didChange = false
        for entry in entries {
            guard let path = entry.discoveryPath else { continue }
            if let existing = paths[entry.id], existing.savedDate >= path.savedDate { continue }
            paths[entry.id] = path
            didChange = true
        }
        if didChange { persist() }
    }

    // MARK: - Persistence

    private func persist() {
        let encodable = Dictionary(
            uniqueKeysWithValues: paths.map { (String($0.key), $0.value) }
        )
        do {
            let data = try JSONEncoder().encode(encodable)
            defaults.set(data, forKey: Self.key)
        } catch {
            print("DiscoveryPathStore: persist failed: \(error.localizedDescription)")
        }
    }
}
