//
//  MovieLibrary.swift
//  MoodE
//

import Foundation
import Observation

/// Local, account-free library persisted in UserDefaults:
/// watchlist ("Da vedere") and seen movies ("Già visti").
@Observable
final class MovieLibrary {
    private(set) var watchlist: [TMDBMovie]
    private(set) var seen: [TMDBMovie]

    private static let watchlistKey = "movieLibrary.watchlist"
    private static let seenKey = "movieLibrary.seen"

    init() {
        watchlist = Self.loadMovies(forKey: Self.watchlistKey)
        seen = Self.loadMovies(forKey: Self.seenKey)
    }

    // MARK: - Queries

    func isInWatchlist(_ movieID: Int) -> Bool {
        watchlist.contains { $0.id == movieID }
    }

    func isSeen(_ movieID: Int) -> Bool {
        seen.contains { $0.id == movieID }
    }

    // MARK: - Actions

    /// Adds the movie to the watchlist, or removes it if already saved.
    func toggleWatchlist(_ movie: TMDBMovie) {
        if isInWatchlist(movie.id) {
            watchlist.removeAll { $0.id == movie.id }
        } else {
            watchlist.insert(movie, at: 0)
        }
        persist(watchlist, forKey: Self.watchlistKey)
    }

    /// Marks the movie as seen (removing it from the watchlist), or unmarks it.
    func toggleSeen(_ movie: TMDBMovie) {
        if isSeen(movie.id) {
            seen.removeAll { $0.id == movie.id }
        } else {
            seen.insert(movie, at: 0)
            if isInWatchlist(movie.id) {
                watchlist.removeAll { $0.id == movie.id }
                persist(watchlist, forKey: Self.watchlistKey)
            }
        }
        persist(seen, forKey: Self.seenKey)
    }

    // MARK: - Persistence

    private func persist(_ movies: [TMDBMovie], forKey key: String) {
        do {
            let data = try JSONEncoder().encode(movies)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("MovieLibrary: failed to persist \(key): \(error.localizedDescription)")
        }
    }

    private static func loadMovies(forKey key: String) -> [TMDBMovie] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([TMDBMovie].self, from: data)) ?? []
    }
}
