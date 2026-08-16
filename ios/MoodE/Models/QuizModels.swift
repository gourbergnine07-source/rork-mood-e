//
//  QuizModels.swift
//  MoodE
//

import SwiftUI

/// How a quiz turns the collected answers into a result.
enum QuizScoring: Hashable {
    /// Every answer adds weight to one or two outcomes; the heaviest wins.
    case weighted
    /// Every answer is worth points; the total lands on a level ladder.
    case points
}

/// One selectable answer of a quiz question.
struct QuizOption: Identifiable, Hashable {
    /// Key used to store the points of a level-based quiz.
    static let pointsKey = "__points"

    let id: String
    let emoji: String
    /// Weight per outcome id, or the answer's points under `pointsKey`.
    let weights: [String: Int]

    init(id: String, emoji: String, weights: [String: Int]) {
        self.id = id
        self.emoji = emoji
        self.weights = weights
    }

    /// Level-based convenience: a single point value instead of weights.
    init(id: String, emoji: String, points: Int) {
        self.init(id: id, emoji: emoji, weights: [Self.pointsKey: points])
    }

    var points: Int { weights[Self.pointsKey] ?? 0 }

    /// Localized answer text, resolved with the quiz prefix and question id.
    func text(prefix: String, question: String) -> String {
        L("\(prefix).\(question).\(id)")
    }
}

/// One multiple-choice question.
struct QuizQuestion: Identifiable, Hashable {
    let id: String
    let options: [QuizOption]

    func prompt(prefix: String) -> String { L("\(prefix).\(id).q") }
}

/// One possible result of a quiz: a personality profile, a secret genre or a
/// level on a ladder, depending on the quiz's scoring style.
struct QuizOutcome: Identifiable, Hashable {
    let id: String
    /// Localization base: `.title` and `.desc` are appended.
    let keyBase: String
    let emoji: String
    /// SF Symbol fallback when the emoji font is unavailable.
    let icon: String
    let gradient: [Color]
    /// Minimum total points to reach this level (level-based quizzes only).
    var minPoints: Int = 0
    /// Ready-made mood + goal suggestion, for quizzes that end with an
    /// immediate recommendation instead of a pure profile.
    var advice: MoodSelection?

    var title: String { L("\(keyBase).title") }
    var detail: String { L("\(keyBase).desc") }
}

/// Identity of each quiz in the catalog. The raw value is persisted inside
/// saved results, so never rename an existing case.
enum QuizKind: String, CaseIterable, Identifiable, Hashable {
    case spectator
    case decade
    case secretGenre
    case tonight
    case cinephile

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .spectator: return "🎭"
        case .decade: return "📼"
        case .secretGenre: return "🕵️"
        case .tonight: return "🌙"
        case .cinephile: return "🎟️"
        }
    }

    var icon: String {
        switch self {
        case .spectator: return "theatermasks.fill"
        case .decade: return "recordingtape"
        case .secretGenre: return "magnifyingglass.circle.fill"
        case .tonight: return "moon.stars.fill"
        case .cinephile: return "ticket.fill"
        }
    }

    /// Signature gradient of the quiz card in the hub.
    var gradient: [Color] {
        switch self {
        case .spectator:
            return [Color(red: 0.55, green: 0.24, blue: 0.62), Color(red: 0.88, green: 0.35, blue: 0.45)]
        case .decade:
            return [Color(red: 0.83, green: 0.45, blue: 0.16), Color(red: 0.47, green: 0.20, blue: 0.35)]
        case .secretGenre:
            return [Color(red: 0.11, green: 0.35, blue: 0.44), Color(red: 0.05, green: 0.14, blue: 0.24)]
        case .tonight:
            return [Color(red: 0.27, green: 0.29, blue: 0.66), Color(red: 0.61, green: 0.36, blue: 0.72)]
        case .cinephile:
            return [Color(red: 0.72, green: 0.55, blue: 0.16), Color(red: 0.40, green: 0.22, blue: 0.12)]
        }
    }
}

/// A complete quiz: its questions, its possible outcomes and the way the
/// two are connected. Content lives in the localization tables, so the same
/// definition renders in every supported language.
struct QuizDefinition: Identifiable, Hashable {
    let kind: QuizKind
    /// Localization prefix of every string of this quiz.
    let keyPrefix: String
    let questions: [QuizQuestion]
    let outcomes: [QuizOutcome]
    let scoring: QuizScoring

    var id: String { kind.rawValue }

    var title: String { L("\(keyPrefix).title") }
    /// One-line description shown on the hub card.
    var tagline: String { L("\(keyPrefix).card.sub") }
    var introMessage: String { L("\(keyPrefix).intro.msg") }

    /// Highest reachable score, used to show "13/18 punti".
    var maxPoints: Int {
        questions.reduce(0) { total, question in
            total + (question.options.map(\.points).max() ?? 0)
        }
    }

    func outcome(id: String) -> QuizOutcome? {
        outcomes.first { $0.id == id }
    }

    /// Level matching a total score: the highest one the user reached.
    func outcome(points: Int) -> QuizOutcome? {
        outcomes
            .filter { points >= $0.minPoints }
            .max { $0.minPoints < $1.minPoints }
            ?? outcomes.first
    }
}
