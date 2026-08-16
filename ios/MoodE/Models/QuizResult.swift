//
//  QuizResult.swift
//  MoodE
//

import Foundation

/// One result obtained by the user: which quiz, which outcome, when.
///
/// Results are only kept when the user explicitly taps "Conserva", and there
/// is no limit: the same quiz can be retaken and kept as many times as
/// wanted, so the collection becomes a little timeline of moods over months.
/// Only ids are persisted, so the stored result renders in whatever language
/// is active when it is read back.
nonisolated struct QuizResult: Identifiable, Codable, Hashable {
    let id: UUID
    /// `QuizKind` raw value.
    let quizId: String
    /// `QuizOutcome` id inside that quiz.
    let outcomeId: String
    let date: Date
    /// Total score, for level-based quizzes only.
    let points: Int?

    init(
        id: UUID = UUID(),
        quizId: String,
        outcomeId: String,
        date: Date = Date(),
        points: Int? = nil
    ) {
        self.id = id
        self.quizId = quizId
        self.outcomeId = outcomeId
        self.date = date
        self.points = points
    }
}

extension QuizResult {
    /// Quiz this result belongs to, or nil if it was produced by a version
    /// of the app that had a quiz we no longer ship.
    @MainActor
    var definition: QuizDefinition? {
        QuizCatalog.definition(id: quizId)
    }

    @MainActor
    var outcome: QuizOutcome? {
        definition?.outcome(id: outcomeId)
    }

    /// False for results whose quiz or outcome disappeared: the UI skips them
    /// instead of showing an empty row.
    @MainActor
    var isRenderable: Bool { outcome != nil }

    /// "13/18 punti" for level-based quizzes, nil for the others.
    @MainActor
    var scoreText: String? {
        guard let points, let definition, definition.scoring == .points else { return nil }
        return LF("quiz.result.points", points, definition.maxPoints)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = L10nStore.currentLocale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
