//
//  LiveEvent.swift
//  MoodE
//

import SwiftUI

/// One recurring live cinema event (award night, festival opening).
/// Central config, same approach as `FeaturedCalendar`: the home countdown
/// card, the dedicated collection and the notifications all derive from it.
struct LiveEvent: Identifiable, Hashable {
    let id: String
    let emoji: String
    /// SF Symbol fallback when the emoji font is unavailable.
    let icon: String
    /// Recurring yearly date (month/day).
    let month: Int
    let day: Int
    /// TMDB source of the related movie collection.
    let source: FeaturedSource
    let gradient: [Color]

    var title: String { LN("featured.\(id).title") }
    var detail: String { LN("featured.\(id).sub") }

    /// The tappable collection reuses the featured-collection screen.
    var collection: FeaturedCollection {
        FeaturedCollection(id: id, emoji: emoji, icon: icon, period: nil, source: source, gradient: gradient)
    }

    /// Next occurrence of the event day (start of day) on or after `date`.
    func nextDate(onOrAfter date: Date = Date()) -> Date? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        let year = calendar.component(.year, from: today)
        for candidateYear in [year, year + 1] {
            var components = DateComponents()
            components.year = candidateYear
            components.month = month
            components.day = day
            if let candidate = calendar.date(from: components),
               calendar.startOfDay(for: candidate) >= today {
                return calendar.startOfDay(for: candidate)
            }
        }
        return nil
    }

    /// Whole days between today and the next occurrence (0 = today).
    func daysUntil(from date: Date = Date()) -> Int? {
        let calendar = Calendar.current
        guard let next = nextDate(onOrAfter: date) else { return nil }
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: next
        ).day
    }
}

/// Central live-event calendar: the single place to add or edit events.
enum LiveEventCalendar {
    static let all: [LiveEvent] = [
        LiveEvent(
            id: "oscarNight",
            emoji: "🏆",
            icon: "trophy.fill",
            month: 3, day: 15,
            source: .discover(FeaturedQuery(
                voteCountGte: 300,
                voteAverageGte: 7.2,
                releasedWithinMonths: 18
            )),
            gradient: [Color(red: 0.80, green: 0.62, blue: 0.20), Color(red: 0.35, green: 0.24, blue: 0.06)]
        ),
        LiveEvent(
            id: "cannes",
            emoji: "🌴",
            icon: "film.fill",
            month: 5, day: 12,
            source: .discover(FeaturedQuery(
                voteCountGte: 200,
                voteAverageGte: 7.4,
                releasedWithinMonths: 36
            )),
            gradient: [Color(red: 0.83, green: 0.34, blue: 0.28), Color(red: 0.22, green: 0.32, blue: 0.52)]
        ),
        LiveEvent(
            id: "locarno",
            emoji: "🐆",
            icon: "sparkles.tv.fill",
            month: 8, day: 5,
            source: .discover(FeaturedQuery(
                voteCountGte: 100,
                voteAverageGte: 7.0,
                releasedWithinMonths: 36
            )),
            gradient: [Color(red: 0.86, green: 0.65, blue: 0.14), Color(red: 0.20, green: 0.20, blue: 0.20)]
        ),
        LiveEvent(
            id: "venezia",
            emoji: "🎭",
            icon: "theatermasks.fill",
            month: 8, day: 27,
            source: .discover(FeaturedQuery(
                voteCountGte: 150,
                voteAverageGte: 7.3,
                releasedWithinMonths: 24
            )),
            gradient: [Color(red: 0.72, green: 0.16, blue: 0.24), Color(red: 0.80, green: 0.62, blue: 0.20)]
        )
    ]

    /// Events within the next `days` days, nearest first.
    static func upcoming(within days: Int = 14, from date: Date = Date()) -> [(event: LiveEvent, days: Int)] {
        all
            .compactMap { event in
                event.daysUntil(from: date).map { (event: event, days: $0) }
            }
            .filter { $0.days <= days }
            .sorted { $0.days < $1.days }
    }
}
