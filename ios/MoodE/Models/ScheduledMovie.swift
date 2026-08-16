//
//  ScheduledMovie.swift
//  MoodE
//

import Foundation

/// A movie planned on a specific diary day, persisted locally.
nonisolated struct ScheduledMovie: Codable, Identifiable, Hashable {
    let id: UUID
    let movieId: Int
    let title: String
    let posterPath: String?
    let genreIds: [Int]?
    var day: Date

    var posterURL: URL? {
        guard let posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")
    }

    /// Minimal movie used to open the shared detail screen (full data is
    /// fetched there). Keeps the diary and the memories gallery on the very
    /// same detail page, with no duplicated logic.
    var asMovie: TMDBMovie {
        TMDBMovie(
            id: movieId,
            title: title,
            overview: "",
            posterPath: posterPath,
            backdropPath: nil,
            releaseDate: nil,
            voteAverage: 0,
            voteCount: 0,
            genreIds: genreIds
        )
    }
}

/// A watched planned movie turned into a personal memory:
/// emoji rating (1...5) plus an optional short comment.
nonisolated struct MovieMemory: Codable, Identifiable, Hashable {
    let id: UUID
    let movieId: Int
    let title: String
    let posterPath: String?
    let genreIds: [Int]?
    let watchedDate: Date
    var rating: Int
    var comment: String?

    var posterURL: URL? {
        guard let posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")
    }

    var ratingEmoji: String { EmojiRating.emoji(for: rating) }

    /// Minimal movie used to open the shared detail screen, so a memory
    /// opens exactly the same page as any other movie in the app.
    var asMovie: TMDBMovie {
        TMDBMovie(
            id: movieId,
            title: title,
            overview: "",
            posterPath: posterPath,
            backdropPath: nil,
            releaseDate: nil,
            voteAverage: 0,
            voteCount: 0,
            genreIds: genreIds
        )
    }
}

/// The 5-level emoji scale used instead of stars, in line with the
/// emotional tone of the app.
nonisolated enum EmojiRating {
    static let range = 1...5

    static func emoji(for value: Int) -> String {
        switch value {
        case ...1: return "😞"
        case 2: return "😐"
        case 3: return "🙂"
        case 4: return "😍"
        default: return "🤩"
        }
    }
}
