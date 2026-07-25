//
//  SearchHistory.swift
//  MoodE
//

import Foundation
import Observation

/// Local history of the user's recent searches, shown as quick suggestion
/// chips under a search bar. Stored only on device (UserDefaults), capped
/// at 5 entries, most recent first, deduplicated case-insensitively.
/// One instance per search surface (TV shows, Al Cinema).
@Observable
final class SearchHistory {
    /// "Emissioni televisive" TV show search.
    static let tv = SearchHistory(storageKey: "tv.search.recent")
    /// Al Cinema movie search.
    static let cinema = SearchHistory(storageKey: "cinema.search.recent")

    private static let maxEntries = 5

    private let storageKey: String
    private(set) var items: [String]

    private init(storageKey: String) {
        self.storageKey = storageKey
        items = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
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
        UserDefaults.standard.set(items, forKey: storageKey)
    }
}
