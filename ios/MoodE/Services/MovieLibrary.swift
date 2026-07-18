//
//  MovieLibrary.swift
//  MoodE
//

import Foundation
import Observation

/// Lifecycle status of a saved movie.
nonisolated enum LibraryStatus: String, Codable {
    case toWatch = "to_watch"
    case watched = "watched"
}

/// Movie saved in the local library, persisted as JSON:
/// { id, title, poster_path, status, addedDate, watchedDate }.
nonisolated struct LibraryEntry: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let posterPath: String?
    var status: LibraryStatus
    var addedDate: Date
    var watchedDate: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, status, addedDate, watchedDate
        case posterPath = "poster_path"
    }

    /// Poster URL (w500) for the saved movie.
    var posterURL: URL? {
        guard let posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")
    }

    /// Minimal TMDBMovie used to open the detail screen (full data is fetched there).
    var asMovie: TMDBMovie {
        TMDBMovie(
            id: id,
            title: title,
            overview: "",
            posterPath: posterPath,
            backdropPath: nil,
            releaseDate: nil,
            voteAverage: 0,
            voteCount: 0,
            genreIds: nil
        )
    }
}

/// Local, account-free movie library persisted in UserDefaults.
/// A single entry moves between "to watch" and "watched" states in real time.
@Observable
final class MovieLibrary {
    private(set) var entries: [LibraryEntry]

    /// When true, watched movies are removed automatically 7 days after
    /// being marked as seen (they may then reappear in recommendations).
    var autoRemoveWatchedAfterWeek: Bool {
        didSet {
            UserDefaults.standard.set(autoRemoveWatchedAfterWeek, forKey: Self.autoRemoveKey)
            if autoRemoveWatchedAfterWeek { pruneExpiredWatched() }
        }
    }

    private static let entriesKey = "movieLibrary.entries"
    private static let legacyWatchlistKey = "movieLibrary.watchlist"
    private static let legacySeenKey = "movieLibrary.seen"
    private static let autoRemoveKey = "movieLibrary.autoRemoveWatched"
    /// One week, the retention window for auto-removal of watched movies.
    private static let watchedRetention: TimeInterval = 7 * 24 * 60 * 60

    init() {
        entries = Self.loadEntries()
        autoRemoveWatchedAfterWeek = UserDefaults.standard.bool(forKey: Self.autoRemoveKey)
        pruneExpiredWatched()
    }

    // MARK: - Derived lists

    /// Movies saved but not watched yet, newest first.
    var toWatch: [LibraryEntry] {
        entries
            .filter { $0.status == .toWatch }
            .sorted { $0.addedDate > $1.addedDate }
    }

    /// Movies marked as watched, most recently watched first.
    var watched: [LibraryEntry] {
        entries
            .filter { $0.status == .watched }
            .sorted { ($0.watchedDate ?? .distantPast) > ($1.watchedDate ?? .distantPast) }
    }

    /// Badge count for the tab bar.
    var toWatchCount: Int {
        entries.filter { $0.status == .toWatch }.count
    }

    /// IDs of watched movies, used to exclude them from recommendations.
    var watchedIds: Set<Int> {
        Set(entries.filter { $0.status == .watched }.map(\.id))
    }

    // MARK: - Queries

    func entry(for movieID: Int) -> LibraryEntry? {
        entries.first { $0.id == movieID }
    }

    func isInWatchlist(_ movieID: Int) -> Bool {
        entry(for: movieID)?.status == .toWatch
    }

    func isSeen(_ movieID: Int) -> Bool {
        entry(for: movieID)?.status == .watched
    }

    // MARK: - Actions

    /// Adds the movie to "to watch", or removes it if already saved there.
    /// A watched movie moves back to "to watch".
    func toggleWatchlist(_ movie: TMDBMovie) {
        if let index = entries.firstIndex(where: { $0.id == movie.id }) {
            if entries[index].status == .toWatch {
                entries.remove(at: index)
            } else {
                entries[index].status = .toWatch
                entries[index].addedDate = Date()
                entries[index].watchedDate = nil
            }
        } else {
            entries.insert(makeEntry(from: movie, status: .toWatch), at: 0)
        }
        persist()
    }

    /// Marks the movie as watched (leaving "to watch" automatically),
    /// or unmarks it removing the entry.
    func toggleSeen(_ movie: TMDBMovie) {
        if let index = entries.firstIndex(where: { $0.id == movie.id }) {
            if entries[index].status == .watched {
                entries.remove(at: index)
            } else {
                entries[index].status = .watched
                entries[index].watchedDate = Date()
            }
        } else {
            var entry = makeEntry(from: movie, status: .watched)
            entry.watchedDate = Date()
            entries.insert(entry, at: 0)
        }
        persist()
    }

    /// Quick action from the list: flips an existing entry to "watched".
    func markWatched(_ entryID: Int) {
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else { return }
        entries[index].status = .watched
        entries[index].watchedDate = Date()
        persist()
    }

    /// Manually removes an entry from the library (e.g. from the "Già visti" list).
    func removeEntry(_ entryID: Int) {
        let before = entries.count
        entries.removeAll { $0.id == entryID }
        if entries.count != before { persist() }
    }

    /// Drops watched movies older than one week when auto-removal is enabled.
    func pruneExpiredWatched() {
        guard autoRemoveWatchedAfterWeek else { return }
        let cutoff = Date().addingTimeInterval(-Self.watchedRetention)
        let before = entries.count
        entries.removeAll { entry in
            entry.status == .watched && (entry.watchedDate ?? .distantPast) < cutoff
        }
        if entries.count != before { persist() }
    }

    private func makeEntry(from movie: TMDBMovie, status: LibraryStatus) -> LibraryEntry {
        LibraryEntry(
            id: movie.id,
            title: movie.title,
            posterPath: movie.posterPath,
            status: status,
            addedDate: Date(),
            watchedDate: nil
        )
    }

    // MARK: - Persistence

    private func persist() {
        do {
            let data = try JSONEncoder().encode(entries)
            UserDefaults.standard.set(data, forKey: Self.entriesKey)
        } catch {
            print("MovieLibrary: failed to persist entries: \(error.localizedDescription)")
        }
    }

    private static func loadEntries() -> [LibraryEntry] {
        if let data = UserDefaults.standard.data(forKey: entriesKey),
           let entries = try? JSONDecoder().decode([LibraryEntry].self, from: data) {
            return entries
        }
        return migrateLegacyStorage()
    }

    /// One-time migration from the previous storage format (two movie arrays).
    private static func migrateLegacyStorage() -> [LibraryEntry] {
        let defaults = UserDefaults.standard
        var migrated: [LibraryEntry] = []

        if let data = defaults.data(forKey: legacyWatchlistKey),
           let movies = try? JSONDecoder().decode([TMDBMovie].self, from: data) {
            migrated += movies.map {
                LibraryEntry(
                    id: $0.id, title: $0.title, posterPath: $0.posterPath,
                    status: .toWatch, addedDate: Date(), watchedDate: nil
                )
            }
        }

        if let data = defaults.data(forKey: legacySeenKey),
           let movies = try? JSONDecoder().decode([TMDBMovie].self, from: data) {
            for movie in movies where !migrated.contains(where: { $0.id == movie.id }) {
                migrated.append(
                    LibraryEntry(
                        id: movie.id, title: movie.title, posterPath: movie.posterPath,
                        status: .watched, addedDate: Date(), watchedDate: Date()
                    )
                )
            }
        }

        if !migrated.isEmpty {
            if let data = try? JSONEncoder().encode(migrated) {
                defaults.set(data, forKey: entriesKey)
            }
            defaults.removeObject(forKey: legacyWatchlistKey)
            defaults.removeObject(forKey: legacySeenKey)
        }

        return migrated
    }
}
