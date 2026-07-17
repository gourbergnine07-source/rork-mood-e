//
//  TMDBCache.swift
//  MoodE
//

import Foundation

/// Timestamped wrapper persisted on disk for each cached payload.
nonisolated struct TMDBCacheEntry<T: Codable>: Codable {
    let timestamp: Date
    let value: T
}

/// Local cache for TMDB responses with a 6-hour freshness window.
/// Data younger than the window is served without calling the API;
/// older data is shown instantly while a background refresh runs.
nonisolated enum TMDBCache {
    /// Cached data younger than this is considered fresh (6 hours).
    static let freshnessWindow: TimeInterval = 6 * 60 * 60

    private static let keyPrefix = "tmdbCache."

    /// Persists a payload with the current timestamp.
    static func save<T: Codable>(_ value: T, forKey key: String) {
        let entry = TMDBCacheEntry(timestamp: Date(), value: value)
        do {
            let data = try JSONEncoder().encode(entry)
            UserDefaults.standard.set(data, forKey: keyPrefix + key)
        } catch {
            print("TMDBCache: failed to save \(key): \(error.localizedDescription)")
        }
    }

    /// Loads a cached payload, reporting whether it is still fresh (< 6h old).
    static func load<T: Codable>(_ type: T.Type, forKey key: String) -> (value: T, isFresh: Bool)? {
        guard let data = UserDefaults.standard.data(forKey: keyPrefix + key),
              let entry = try? JSONDecoder().decode(TMDBCacheEntry<T>.self, from: data) else {
            return nil
        }
        let age = Date().timeIntervalSince(entry.timestamp)
        return (entry.value, age < freshnessWindow)
    }
}
