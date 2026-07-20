//
//  FeaturedCollection.swift
//  MoodE
//

import SwiftUI

/// TMDB discover filters behind an editorial collection.
struct FeaturedQuery: Hashable {
    var genres: [Int] = []
    var keywords: [Int] = []
    var voteCountGte: Int = 300
    var voteAverageGte: Double?
    /// Restricts to movies released within the last N months (Oscar race).
    var releasedWithinMonths: Int?
    var sortBy: String = "vote_average.desc"
    var includeHorror: Bool = false
}

/// Where an editorial collection gets its movies from.
enum FeaturedSource: Hashable {
    case discover(FeaturedQuery)
    case trendingWeek
}

/// Recurring yearly window (both bounds inclusive, no year wrap).
struct SeasonalPeriod: Hashable {
    let startMonth: Int
    let startDay: Int
    let endMonth: Int
    let endDay: Int

    /// True when the date falls inside the window (any year).
    func contains(_ date: Date) -> Bool {
        let parts = Calendar.current.dateComponents([.month, .day], from: date)
        guard let month = parts.month, let day = parts.day else { return false }
        let value = month * 100 + day
        return value >= startMonth * 100 + startDay && value <= endMonth * 100 + endDay
    }

    /// Next occurrence of the window's first day strictly after `date`.
    func nextStart(after date: Date) -> Date? {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        for candidateYear in [year, year + 1] {
            var components = DateComponents()
            components.year = candidateYear
            components.month = startMonth
            components.day = startDay
            components.hour = 10
            if let start = calendar.date(from: components), start > date {
                return start
            }
        }
        return nil
    }
}

/// One editorial/thematic collection shown in the "In evidenza" strip.
struct FeaturedCollection: Identifiable, Hashable {
    let id: String
    let emoji: String
    /// SF Symbol fallback when the emoji font is unavailable.
    let icon: String
    /// Active window; nil = evergreen (always shown, e.g. weekly picks).
    let period: SeasonalPeriod?
    let source: FeaturedSource
    /// Card gradient colors (white text sits on top).
    let gradient: [Color]

    var title: String { LN("featured.\(id).title") }
    var subtitle: String { LN("featured.\(id).sub") }
}

/// Central theme calendar: the single place to add, remove or edit
/// editorial collections. The rest of the app derives everything
/// (strip cards, TMDB queries, seasonal notifications) from this list,
/// so a future remote-config version only needs to replace this data.
enum FeaturedCalendar {
    static let all: [FeaturedCollection] = [
        FeaturedCollection(
            id: "halloween",
            emoji: "🎃",
            icon: "moon.stars.fill",
            period: SeasonalPeriod(startMonth: 10, startDay: 1, endMonth: 10, endDay: 31),
            source: .discover(FeaturedQuery(
                genres: [TMDBGenre.horror, TMDBGenre.thriller],
                voteCountGte: 500,
                includeHorror: true
            )),
            gradient: [Color(red: 0.91, green: 0.45, blue: 0.13), Color(red: 0.35, green: 0.15, blue: 0.45)]
        ),
        FeaturedCollection(
            id: "valentine",
            emoji: "❤️",
            icon: "heart.fill",
            period: SeasonalPeriod(startMonth: 2, startDay: 1, endMonth: 2, endDay: 14),
            source: .discover(FeaturedQuery(
                genres: [TMDBGenre.romance],
                voteCountGte: 400
            )),
            gradient: [Color(red: 0.90, green: 0.36, blue: 0.47), Color(red: 0.62, green: 0.13, blue: 0.30)]
        ),
        FeaturedCollection(
            id: "christmas",
            emoji: "🎄",
            icon: "gift.fill",
            period: SeasonalPeriod(startMonth: 12, startDay: 1, endMonth: 12, endDay: 26),
            source: .discover(FeaturedQuery(
                genres: [TMDBGenre.family, TMDBGenre.comedy],
                keywords: [TMDBKeyword.christmas],
                voteCountGte: 150
            )),
            gradient: [Color(red: 0.13, green: 0.47, blue: 0.29), Color(red: 0.65, green: 0.15, blue: 0.18)]
        ),
        FeaturedCollection(
            id: "oscars",
            emoji: "🏆",
            icon: "trophy.fill",
            period: SeasonalPeriod(startMonth: 3, startDay: 1, endMonth: 3, endDay: 31),
            source: .discover(FeaturedQuery(
                voteCountGte: 300,
                voteAverageGte: 7.2,
                releasedWithinMonths: 18
            )),
            gradient: [Color(red: 0.80, green: 0.62, blue: 0.20), Color(red: 0.45, green: 0.30, blue: 0.08)]
        ),
        FeaturedCollection(
            id: "pride",
            emoji: "🌈",
            icon: "sparkles",
            period: SeasonalPeriod(startMonth: 6, startDay: 1, endMonth: 6, endDay: 30),
            source: .discover(FeaturedQuery(
                keywords: [TMDBKeyword.lgbt],
                voteCountGte: 200
            )),
            gradient: [Color(red: 0.55, green: 0.27, blue: 0.68), Color(red: 0.89, green: 0.35, blue: 0.42)]
        ),
        FeaturedCollection(
            id: "summer",
            emoji: "☀️",
            icon: "sun.max.fill",
            period: SeasonalPeriod(startMonth: 6, startDay: 1, endMonth: 8, endDay: 31),
            source: .discover(FeaturedQuery(
                genres: [TMDBGenre.comedy, TMDBGenre.adventure],
                voteCountGte: 400,
                voteAverageGte: 6.5,
                sortBy: "popularity.desc"
            )),
            gradient: [Color(red: 0.10, green: 0.60, blue: 0.75), Color(red: 0.95, green: 0.65, blue: 0.25)]
        ),
        FeaturedCollection(
            id: "weekly",
            emoji: "🍿",
            icon: "popcorn.fill",
            period: nil,
            source: .trendingWeek,
            gradient: [Color(red: 0.35, green: 0.35, blue: 0.72), Color(red: 0.20, green: 0.16, blue: 0.42)]
        )
    ]

    /// Collections tied to a yearly window (used for seasonal notifications).
    static var seasonal: [FeaturedCollection] {
        all.filter { $0.period != nil }
    }

    /// Cards to show today: active seasonal themes first (config order),
    /// evergreen collections always at the end — the strip is never empty.
    static func activeCollections(on date: Date = Date()) -> [FeaturedCollection] {
        let active = all.filter { $0.period?.contains(date) == true }
        let evergreen = all.filter { $0.period == nil }
        return active + evergreen
    }
}
