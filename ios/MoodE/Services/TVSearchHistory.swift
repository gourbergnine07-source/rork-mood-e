//
//  TVSearchHistory.swift
//  MoodE
//

import Foundation
import Observation

/// Local history of the user's last TV searches, shown as quick
/// suggestions under the search bar in "Emissioni televisive".
/// Stored only on device (UserDefaults), capped at 5 entries,
/// most recent first, deduplicated case-insensitively.
@Observable
final class TVSearchHistory {
    static let shared = TVSearchHistory()

    private static let storageKey = "tv.search.recent"
    private static let maxEntries = 5

    private(set) var items: [String]

    private init() {
        items = UserDefaults.standard.stringArray(forKey: Self.storageKey) ?? []
    }

    /// Records a search: trims it, moves duplicates to the top and
    /// keeps only the 5 most recent queries.
    func add(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        items.removeAll { $0.compare(trimmed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
        items.insert(trimmed, at: 0)
        if items.count > Self.maxEntries {
            items = Array(items.prefix(Self.maxEntries))
        }
        persist()
    }

    /// Clears the whole history.
    func clear() {
        items = []
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(items, forKey: Self.storageKey)
    }
}
