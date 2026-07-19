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
}

/// UI accessors (main-actor: they resolve localized enum cases).
extension MoodCheckIn {
    var mood: Mood? { Mood(rawValue: moodRaw) }
    var goal: ViewingGoal? { ViewingGoal(rawValue: goalRaw) }
    var era: MovieEra? { MovieEra(rawValue: eraRaw) }
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
}
