//
//  MovieStatsStore.swift
//  MoodE
//

import Foundation
import Observation

/// Cached per-movie facts (runtime, genres, release year) powering the
/// local "Le mie statistiche" dashboard. Fetched once from TMDB per movie,
/// then persisted in UserDefaults — no repeated network calls.
nonisolated struct MovieFacts: Codable {
    let runtime: Int?
    let genreIds: [Int]
    let year: Int?
}

/// Aggregated, locally computed lifetime cinema statistics.
struct CineStats {
    let watchedCount: Int
    /// Sum of the known runtimes of watched movies, in minutes.
    let totalMinutes: Int
    let topGenreId: Int?
    /// Share (0-100) of watched movies containing the top genre.
    let topGenreShare: Int
    let topMood: Mood?
    /// Start year of the most explored decade (e.g. 1990).
    let topDecade: Int?
    let bestMemory: MovieMemory?
    /// Watched movies per TMDB genre id (each movie counts once per genre).
    let genreCounts: [Int: Int]
}

/// Local statistics engine: merges the watched library and the planner
/// memories, enriches them with cached TMDB facts and aggregates numbers.
@Observable
final class MovieStatsStore {
    private(set) var facts: [Int: MovieFacts]
    private var inFlight: Set<Int> = []

    private static let factsKey = "stats.movieFacts"
    private let defaults = UserDefaults.standard

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.factsKey),
           let stored = try? JSONDecoder().decode([Int: MovieFacts].self, from: data) {
            facts = stored
        } else {
            facts = [:]
        }
    }

    /// Unique watched movie ids across the library and the planner memories.
    static func watchedIds(watched: [LibraryEntry], memories: [MovieMemory]) -> Set<Int> {
        Set(watched.map(\.id)).union(memories.map(\.movieId))
    }

    /// Fetches missing facts from TMDB (at most `limit` new movies per call)
    /// and persists them. Safe to call on every screen appearance.
    func refresh(watched: [LibraryEntry], memories: [MovieMemory], limit: Int = 25) async {
        let missing = Self.watchedIds(watched: watched, memories: memories)
            .filter { facts[$0] == nil && !inFlight.contains($0) }
        let ids = Array(missing.prefix(limit))
        guard !ids.isEmpty else { return }

        inFlight.formUnion(ids)
        defer { inFlight.subtract(ids) }

        var updated = false
        for id in ids {
            guard let detail = try? await TMDBService.movieDetail(id: id) else { continue }
            facts[id] = MovieFacts(
                runtime: detail.runtime,
                genreIds: detail.genres.map(\.id),
                year: detail.releaseYear.flatMap { Int($0) }
            )
            updated = true
        }
        if updated { persist() }
    }

    /// Watched movies per genre, from cached facts with the locally stored
    /// memory genres as fallback while facts are still loading.
    func genreCounts(watched: [LibraryEntry], memories: [MovieMemory]) -> [Int: Int] {
        var memoryGenres: [Int: [Int]] = [:]
        for memory in memories {
            if let genres = memory.genreIds, !genres.isEmpty {
                memoryGenres[memory.movieId] = genres
            }
        }

        var counts: [Int: Int] = [:]
        for id in Self.watchedIds(watched: watched, memories: memories) {
            let genres = facts[id]?.genreIds ?? memoryGenres[id] ?? []
            for genre in Set(genres) {
                counts[genre, default: 0] += 1
            }
        }
        return counts
    }

    /// Full aggregate snapshot for the statistics dashboard.
    func stats(
        watched: [LibraryEntry],
        memories: [MovieMemory],
        checkIns: [MoodCheckIn],
        lifetimeWatched: Int
    ) -> CineStats {
        let ids = Self.watchedIds(watched: watched, memories: memories)

        var memoryGenres: [Int: [Int]] = [:]
        for memory in memories {
            if let genres = memory.genreIds, !genres.isEmpty {
                memoryGenres[memory.movieId] = genres
            }
        }

        var genreCounts: [Int: Int] = [:]
        var totalMinutes = 0
        var decadeCounts: [Int: Int] = [:]
        var moviesWithGenres = 0

        for id in ids {
            let genres = facts[id]?.genreIds ?? memoryGenres[id] ?? []
            if !genres.isEmpty { moviesWithGenres += 1 }
            for genre in Set(genres) {
                genreCounts[genre, default: 0] += 1
            }
            if let runtime = facts[id]?.runtime, runtime > 0 {
                totalMinutes += runtime
            }
            if let year = facts[id]?.year, year > 1880 {
                decadeCounts[(year / 10) * 10, default: 0] += 1
            }
        }

        let topGenre = genreCounts.max { ($0.value, -$0.key) < ($1.value, -$1.key) }
        let topGenreShare = topGenre.map { entry in
            moviesWithGenres > 0
                ? Int((Double(entry.value) / Double(moviesWithGenres) * 100).rounded())
                : 0
        } ?? 0

        var moodCounts: [String: Int] = [:]
        for checkIn in checkIns {
            moodCounts[checkIn.moodRaw, default: 0] += 1
        }
        let topMood = moodCounts
            .max { ($0.value, $1.key) < ($1.value, $0.key) }
            .flatMap { Mood(rawValue: $0.key) }

        let topDecade = decadeCounts
            .max { ($0.value, -$0.key) < ($1.value, -$1.key) }?
            .key

        let bestMemory = memories.max {
            ($0.rating, $0.watchedDate) < ($1.rating, $1.watchedDate)
        }

        return CineStats(
            watchedCount: max(lifetimeWatched, ids.count),
            totalMinutes: totalMinutes,
            topGenreId: topGenre?.key,
            topGenreShare: topGenreShare,
            topMood: topMood,
            topDecade: topDecade,
            bestMemory: bestMemory,
            genreCounts: genreCounts
        )
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(facts)
            defaults.set(data, forKey: Self.factsKey)
        } catch {
            print("MovieStatsStore: persist failed: \(error.localizedDescription)")
        }
    }
}
