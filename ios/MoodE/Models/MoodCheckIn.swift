//
//  MoodCheckIn.swift
//  MoodE
//

import Foundation

/// Minimal movie info stored with a diary check-in.
nonisolated struct ProposedMovie: Codable, Hashable, Identifiable {
    let id: Int
    let title: String
    let posterPath: String?
    let genreIds: [Int]?

    var posterURL: URL? {
        guard let posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w200\(posterPath)")
    }

    /// Minimal movie used to open the shared detail screen from the diary
    /// (the full record is fetched by the detail view itself).
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
            genreIds: genreIds
        )
    }
}

/// One completed mood flow (full or quick pick), recorded in the local diary.
/// Persisted as JSON in UserDefaults — no account, nothing leaves the device.
nonisolated struct MoodCheckIn: Codable, Identifiable {
    let id: UUID
    let date: Date
    let moodRaw: String
    let goalRaw: String
    let eraRaw: String
    let isQuickPick: Bool
    var proposed: [ProposedMovie]
    /// Optional short personal note ("why I felt this way"), added from the diary.
    /// Optional so older saved check-ins keep decoding fine.
    var note: String?
}

/// UI accessors (main-actor: they resolve localized enum cases).
extension MoodCheckIn {
    var mood: Mood? { Mood(rawValue: moodRaw) }
    var goal: ViewingGoal? { ViewingGoal(rawValue: goalRaw) }
    /// Eras of the flow; multi-selections are stored as "a+b+c" in eraRaw
    /// (single raw values from older check-ins keep decoding fine).
    var eras: [MovieEra] { eraRaw.components(separatedBy: "+").compactMap(MovieEra.init) }
    var era: MovieEra? { eras.first }
}

/// Snapshot shared with the home-screen widget via the App Group container.
/// Strings are localized at write time so the widget stays language-correct.
nonisolated struct DiaryWidgetSnapshot: Codable {
    let moodEmoji: String
    let moodTitle: String
    let headline: String
    let movieId: Int?
    let movieTitle: String?
    let posterPath: String?
    let updatedAt: Date
    /// Localized "How do you feel?" header for the interactive widget.
    /// Optional so snapshots written by older app versions keep decoding.
    var quickTitle: String?
    /// The user's most-used moods, tappable directly from the widget.
    var quickMoods: [WidgetQuickMood]?
}

/// Compact mood option for the interactive widget (title pre-localized).
nonisolated struct WidgetQuickMood: Codable {
    let raw: String
    let emoji: String
    let title: String
}
