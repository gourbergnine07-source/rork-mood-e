//
//  RecommendationRegistry.swift
//  MoodE
//

import Foundation

/// Remembers which emotion each recommended movie was proposed for, so
/// batches for different emotions never repeat the same titles. A movie
/// shown under "triste" won't reappear under "felice" for 7 days, keeping
/// every emotion's list distinct and recognizable. Stored on device only.
final class RecommendationRegistry {
    static let shared = RecommendationRegistry()

    private nonisolated struct Entry: Codable {
        let mood: String
        let date: Date
    }

    private var entries: [Int: Entry]

    private static let storageKey = "recommendations.moodRegistry"
    /// How long a movie stays assigned to an emotion.
    private static let ttl: TimeInterval = 7 * 24 * 3600
    /// Cap so the registry never grows unbounded.
    private static let maxEntries = 600

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([Int: Entry].self, from: data) {
            let now = Date()
            entries = decoded.filter { now.timeIntervalSince($0.value.date) < Self.ttl }
        } else {
            entries = [:]
        }
    }

    /// Movie ids recently proposed for a DIFFERENT emotion: excluded from
    /// the given mood's batches so lists never overlap between emotions.
    func excludedIds(for mood: Mood) -> Set<Int> {
        let now = Date()
        var ids: Set<Int> = []
        for (id, entry) in entries
        where entry.mood != mood.rawValue && now.timeIntervalSince(entry.date) < Self.ttl {
            ids.insert(id)
        }
        return ids
    }

    /// Assigns a batch to an emotion. The first emotion a movie is shown
    /// for wins; showing it again for the same emotion refreshes the timer.
    func register(_ movies: [TMDBMovie], for mood: Mood) {
        guard !movies.isEmpty else { return }
        let now = Date()
        for movie in movies {
            if let existing = entries[movie.id],
               existing.mood != mood.rawValue,
               now.timeIntervalSince(existing.date) < Self.ttl {
                continue
            }
            entries[movie.id] = Entry(mood: mood.rawValue, date: now)
        }
        prune()
        save()
    }

    private func prune() {
        let now = Date()
        entries = entries.filter { now.timeIntervalSince($0.value.date) < Self.ttl }
        guard entries.count > Self.maxEntries else { return }
        let sorted = entries.sorted { $0.value.date > $1.value.date }
        entries = Dictionary(uniqueKeysWithValues: Array(sorted.prefix(Self.maxEntries)))
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
