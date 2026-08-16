//
//  QuizStore.swift
//  MoodE
//

import Foundation
import Observation

/// Runs the quiz catalog: computes results, keeps the ones the user decides to
/// preserve, and applies the spectator profile as a light extra ranking factor
/// in the movie recommendations.
///
/// Nothing is capped: any quiz can be retaken as often as wanted and every
/// result can be kept, so the collection grows into a small personal timeline.
@Observable
final class QuizStore {
    /// Spectator profile of the latest "Che spettatore sei?" run. It is the
    /// only outcome that feeds the recommendations ranking.
    private(set) var profile: SpectatorProfile?
    private(set) var completedDate: Date?

    /// Results explicitly kept by the user, newest first.
    private(set) var savedResults: [QuizResult]

    /// Last time each quiz was played, keyed by quiz id. Recorded on every
    /// completion, whether or not the result is kept, so the daily suggestion
    /// knows what the user has actually already seen.
    private(set) var playDates: [String: Date]

    private static let profileKey = "quiz.profile"
    private static let dateKey = "quiz.date"
    private static let savedKey = "quiz.savedResults"
    private static let playDatesKey = "quiz.playDates"

    private let defaults = UserDefaults.standard

    init() {
        let defaults = UserDefaults.standard
        profile = defaults.string(forKey: Self.profileKey).flatMap(SpectatorProfile.init)
        completedDate = defaults.object(forKey: Self.dateKey) as? Date
        if let data = defaults.data(forKey: Self.savedKey),
           let stored = try? JSONDecoder().decode([QuizResult].self, from: data) {
            savedResults = stored.sorted { $0.date > $1.date }
        } else {
            savedResults = []
        }
        if let data = defaults.data(forKey: Self.playDatesKey),
           let stored = try? JSONDecoder().decode([String: Date].self, from: data) {
            playDates = stored
        } else {
            playDates = [:]
        }
        // Users coming from an older build have no play history: seed it from
        // the results they kept, so the suggestion starts out informed.
        if playDates.isEmpty, !savedResults.isEmpty {
            for result in savedResults where playDates[result.quizId] == nil {
                playDates[result.quizId] = result.date
            }
            persistPlayDates()
        }
    }

    /// When the given quiz was last played, or nil if never.
    func lastPlayed(quizId: String) -> Date? {
        playDates[quizId]
    }

    // MARK: - Playing

    /// Turns the collected answers into a result. The result is returned but
    /// NOT added to the collection: keeping it is an explicit user choice.
    func complete(_ definition: QuizDefinition, answers: [String: QuizOption]) -> QuizResult {
        recordPlay(definition.id)
        switch definition.scoring {
        case .weighted:
            let winner = weightedWinner(definition, answers: answers)
            if definition.kind == .spectator {
                persistSpectatorProfile(winner)
            }
            AnalyticsService.shared.log(
                "quiz_completed",
                meta: ["quiz": definition.id, "profile": winner]
            )
            return QuizResult(quizId: definition.id, outcomeId: winner)

        case .points:
            let total = answers.values.reduce(0) { $0 + $1.points }
            let level = definition.outcome(points: total)?.id
                ?? definition.outcomes.first?.id
                ?? ""
            AnalyticsService.shared.log(
                "quiz_completed",
                meta: ["quiz": definition.id, "profile": level]
            )
            return QuizResult(quizId: definition.id, outcomeId: level, points: total)
        }
    }

    /// Heaviest outcome; ties break on the catalog order so the same answers
    /// always give the same result.
    private func weightedWinner(_ definition: QuizDefinition, answers: [String: QuizOption]) -> String {
        var scores: [String: Int] = [:]
        for option in answers.values {
            for (outcomeId, weight) in option.weights {
                scores[outcomeId, default: 0] += weight
            }
        }
        let ranked = definition.outcomes.max { lhs, rhs in
            (scores[lhs.id] ?? 0) < (scores[rhs.id] ?? 0)
        }
        return ranked?.id ?? definition.outcomes.first?.id ?? ""
    }

    private func recordPlay(_ quizId: String) {
        playDates[quizId] = Date()
        persistPlayDates()
    }

    private func persistPlayDates() {
        do {
            let data = try JSONEncoder().encode(playDates)
            defaults.set(data, forKey: Self.playDatesKey)
        } catch {
            print("QuizStore: play history persist failed: \(error.localizedDescription)")
        }
    }

    private func persistSpectatorProfile(_ outcomeId: String) {
        guard let winner = SpectatorProfile(rawValue: outcomeId) else { return }
        profile = winner
        completedDate = Date()
        defaults.set(winner.rawValue, forKey: Self.profileKey)
        defaults.set(completedDate, forKey: Self.dateKey)
    }

    // MARK: - Collection

    /// Adds a result to the permanent collection. Idempotent: keeping the same
    /// result twice does nothing.
    func keep(_ result: QuizResult) {
        guard !isKept(result) else { return }
        savedResults.insert(result, at: 0)
        savedResults.sort { $0.date > $1.date }
        persistSaved()
        AnalyticsService.shared.log("quiz_result_kept", meta: ["quiz": result.quizId])
    }

    func remove(_ result: QuizResult) {
        guard savedResults.contains(where: { $0.id == result.id }) else { return }
        savedResults.removeAll { $0.id == result.id }
        persistSaved()
    }

    func isKept(_ result: QuizResult) -> Bool {
        savedResults.contains { $0.id == result.id }
    }

    /// Kept results of one quiz, newest first (a quiz can appear many times).
    func results(forQuiz quizId: String) -> [QuizResult] {
        savedResults.filter { $0.quizId == quizId }
    }

    /// Latest kept result of one quiz, used for the hub card badge.
    func latestResult(forQuiz quizId: String) -> QuizResult? {
        results(forQuiz: quizId).first
    }

    private func persistSaved() {
        do {
            let data = try JSONEncoder().encode(savedResults)
            defaults.set(data, forKey: Self.savedKey)
        } catch {
            print("QuizStore: persist failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Recommendations ranking

    /// Static access used by the results ranking (no environment plumbing).
    static var currentProfile: SpectatorProfile? {
        UserDefaults.standard.string(forKey: profileKey).flatMap(SpectatorProfile.init)
    }

    /// Gentle re-rank: movies matching the profile's favorite genres float a
    /// couple of positions up. The mood→goal→era selection stays dominant.
    static func rerank(_ movies: [TMDBMovie]) -> [TMDBMovie] {
        guard let profile = currentProfile else { return movies }
        let boosted = Set(profile.boostGenres)
        return movies.enumerated()
            .sorted { lhs, rhs in
                score(lhs, boosted: boosted) < score(rhs, boosted: boosted)
            }
            .map(\.element)
    }

    private static func score(_ entry: (offset: Int, element: TMDBMovie), boosted: Set<Int>) -> Double {
        let matches = !(Set(entry.element.genreIds ?? []).isDisjoint(with: boosted))
        return Double(entry.offset) - (matches ? 2.5 : 0)
    }
}
