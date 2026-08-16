//
//  DailyQuizSuggestion.swift
//  MoodE
//

import Foundation
import Observation

/// One day's quiz proposal: which quiz, why it was chosen, and what the user
/// got last time they played it.
struct DailyQuizSuggestion: Identifiable, Hashable {
    let definition: QuizDefinition
    /// Localized one-liner explaining why this quiz shows up today.
    let reason: String
    /// Outcome of the most recent kept result of this quiz, when there is one.
    let previousOutcome: QuizOutcome?

    var id: String { definition.id }
}

/// Chooses one quiz per day, based on what the user already played.
///
/// Ranking, in order:
/// 1. a quiz never played beats one already played;
/// 2. among played ones, the least recently played wins;
/// 3. the quiz proposed yesterday is skipped whenever an alternative exists,
///    so the card never repeats itself two days in a row;
/// 4. ties rotate with the date, so two fresh quizzes don't always resolve
///    in catalog order.
///
/// The pick is frozen for the calendar day: it's computed once, stored, and
/// reused, so reopening the app never reshuffles the card. It retires itself
/// as soon as the suggested quiz is played, and can be hidden for the day.
@Observable
final class DailyQuizStore {
    static let shared = DailyQuizStore()

    /// Today's proposal, or nil when there is nothing to show (already played,
    /// hidden for today, or an empty catalog).
    private(set) var current: DailyQuizSuggestion?

    private static let pickDayKey = "dailyQuiz.pickDay"
    private static let pickIdKey = "dailyQuiz.pickId"
    private static let previousIdKey = "dailyQuiz.previousId"
    private static let hiddenDayKey = "dailyQuiz.hiddenDay"

    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - Refresh

    /// Recomputes today's proposal. Called from the card's `task`, never from a
    /// view body, so the stored pick is written outside of view evaluation.
    func refresh(using store: QuizStore) {
        let today = Self.dayKey(for: Date())

        guard defaults.string(forKey: Self.hiddenDayKey) != today else {
            current = nil
            return
        }

        let catalog = QuizCatalog.all
        guard !catalog.isEmpty else {
            current = nil
            return
        }

        let pick = frozenPick(catalog: catalog, store: store, today: today)
        guard let definition = QuizCatalog.definition(id: pick) else {
            current = nil
            return
        }

        // Played today already: the card steps aside instead of inviting the
        // user to repeat what they just did.
        if let played = store.lastPlayed(quizId: definition.id),
           Calendar.current.isDateInToday(played) {
            current = nil
            return
        }

        let previous = store.latestResult(forQuiz: definition.id)
        current = DailyQuizSuggestion(
            definition: definition,
            reason: reason(for: definition, store: store),
            previousOutcome: previous.flatMap { definition.outcome(id: $0.outcomeId) }
        )
    }

    /// Removes the card until tomorrow.
    func hideForToday() {
        defaults.set(Self.dayKey(for: Date()), forKey: Self.hiddenDayKey)
        current = nil
        AnalyticsService.shared.log("daily_quiz_hidden")
    }

    // MARK: - Choice

    /// Today's stored pick, computing and persisting a new one when the day
    /// changed (or when the stored quiz no longer exists in the catalog).
    private func frozenPick(catalog: [QuizDefinition], store: QuizStore, today: String) -> String {
        if defaults.string(forKey: Self.pickDayKey) == today,
           let stored = defaults.string(forKey: Self.pickIdKey),
           QuizCatalog.definition(id: stored) != nil {
            return stored
        }

        // The pick that is being replaced becomes "yesterday's", the one to avoid.
        let yesterday = defaults.string(forKey: Self.pickIdKey)
        let chosen = choose(catalog: catalog, store: store, today: today, avoiding: yesterday)

        defaults.set(today, forKey: Self.pickDayKey)
        defaults.set(chosen.id, forKey: Self.pickIdKey)
        if let yesterday {
            defaults.set(yesterday, forKey: Self.previousIdKey)
        }
        return chosen.id
    }

    private func choose(
        catalog: [QuizDefinition],
        store: QuizStore,
        today: String,
        avoiding: String?
    ) -> QuizDefinition {
        let pool = catalog.filter { $0.id != avoiding }
        let candidates = pool.isEmpty ? catalog : pool

        let ranked = candidates.sorted { lhs, rhs in
            let left = store.lastPlayed(quizId: lhs.id)
            let right = store.lastPlayed(quizId: rhs.id)
            switch (left, right) {
            case (nil, nil):
                return rotation(lhs, catalog: catalog, today: today)
                    < rotation(rhs, catalog: catalog, today: today)
            case (nil, _):
                return true
            case (_, nil):
                return false
            case (let left?, let right?):
                if left == right {
                    return rotation(lhs, catalog: catalog, today: today)
                        < rotation(rhs, catalog: catalog, today: today)
                }
                return left < right
            }
        }
        return ranked.first ?? catalog[0]
    }

    /// Deterministic per-day ordering used to break ties. `hashValue` is seeded
    /// per process, so the digest is computed by hand to stay stable.
    private func rotation(_ definition: QuizDefinition, catalog: [QuizDefinition], today: String) -> Int {
        guard let index = catalog.firstIndex(where: { $0.id == definition.id }) else { return 0 }
        let seed = today.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return (index + seed) % max(catalog.count, 1)
    }

    // MARK: - Reason

    /// Why this quiz, today — phrased from the user's own history.
    private func reason(for definition: QuizDefinition, store: QuizStore) -> String {
        guard let played = store.lastPlayed(quizId: definition.id) else {
            return store.playDates.isEmpty
                ? L("quiz.daily.reason.first")
                : L("quiz.daily.reason.new")
        }

        if let latest = store.latestResult(forQuiz: definition.id),
           let outcome = definition.outcome(id: latest.outcomeId) {
            return LF("quiz.daily.reason.again", outcome.title)
        }

        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: played),
            to: Calendar.current.startOfDay(for: Date())
        ).day ?? 0
        return days <= 1
            ? L("quiz.daily.reason.new")
            : LF("quiz.daily.reason.back", days)
    }

    // MARK: - Helpers

    /// Stable `yyyy-MM-dd` key in the user's own calendar.
    private static func dayKey(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }
}
