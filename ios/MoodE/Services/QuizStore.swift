//
//  QuizStore.swift
//  MoodE
//

import Foundation
import Observation

/// Persists the spectator-quiz result locally and applies it as a light
/// extra ranking factor in the movie recommendations.
@Observable
final class QuizStore {
    private(set) var profile: SpectatorProfile?
    private(set) var completedDate: Date?

    private static let profileKey = "quiz.profile"
    private static let dateKey = "quiz.date"

    private let defaults = UserDefaults.standard

    init() {
        let defaults = UserDefaults.standard
        profile = defaults.string(forKey: Self.profileKey).flatMap(SpectatorProfile.init)
        completedDate = defaults.object(forKey: Self.dateKey) as? Date
    }

    /// Computes the winning profile from the collected answers and persists it.
    @discardableResult
    func complete(answers: [String: QuizOption]) -> SpectatorProfile {
        var scores: [SpectatorProfile: Int] = [:]
        for option in answers.values {
            for (profile, weight) in option.weights {
                scores[profile, default: 0] += weight
            }
        }
        let winner = scores
            .max { ($0.value, $1.key.rawValue) < ($1.value, $0.key.rawValue) }?
            .key ?? .esploratoreDiGeneri

        profile = winner
        completedDate = Date()
        defaults.set(winner.rawValue, forKey: Self.profileKey)
        defaults.set(completedDate, forKey: Self.dateKey)
        return winner
    }

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
