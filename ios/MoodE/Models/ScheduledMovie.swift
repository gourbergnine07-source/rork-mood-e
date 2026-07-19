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
