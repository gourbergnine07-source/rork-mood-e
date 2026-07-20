//
//  SpectatorQuiz.swift
//  MoodE
//

import Foundation

/// One selectable answer: localized text plus profile score weights.
struct QuizOption: Identifiable, Hashable {
    let id: String
    let emoji: String
    let weights: [SpectatorProfile: Int]

    /// Localized answer text, resolved with the parent question id.
    func text(question: String) -> String { L("quiz.\(question).\(id)") }
}

/// One multiple-choice question of the spectator quiz.
struct QuizQuestion: Identifiable, Hashable {
    let id: String
    let options: [QuizOption]

    var prompt: String { L("quiz.\(id).q") }
}

/// Static catalog of the "Che spettatore sei?" quiz: 6 questions,
/// each answer weighs one or two profiles.
enum SpectatorQuiz {
    static let questions: [QuizQuestion] = [
        QuizQuestion(id: "q1", options: [
            QuizOption(id: "a", emoji: "🛋️", weights: [.sognatoreNostalgico: 2, .romanticoIncallito: 1]),
            QuizOption(id: "b", emoji: "🎬", weights: [.esploratoreDiGeneri: 2, .avventurieroCurioso: 1]),
            QuizOption(id: "c", emoji: "👻", weights: [.cercatoreDiBrividi: 2]),
            QuizOption(id: "d", emoji: "😢", weights: [.animaMalinconica: 2])
        ]),
        QuizQuestion(id: "q2", options: [
            QuizOption(id: "a", emoji: "🥹", weights: [.romanticoIncallito: 2, .animaMalinconica: 1]),
            QuizOption(id: "b", emoji: "🤯", weights: [.cercatoreDiBrividi: 2, .esploratoreDiGeneri: 1]),
            QuizOption(id: "c", emoji: "🌫️", weights: [.animaMalinconica: 2, .esploratoreDiGeneri: 1]),
            QuizOption(id: "d", emoji: "🏆", weights: [.avventurieroCurioso: 2])
        ]),
        QuizQuestion(id: "q3", options: [
            QuizOption(id: "a", emoji: "🙈", weights: [.romanticoIncallito: 1, .sognatoreNostalgico: 1]),
            QuizOption(id: "b", emoji: "💔", weights: [.avventurieroCurioso: 1, .cercatoreDiBrividi: 1]),
            QuizOption(id: "c", emoji: "📚", weights: [.sognatoreNostalgico: 1, .avventurieroCurioso: 1]),
            QuizOption(id: "d", emoji: "🤷", weights: [.esploratoreDiGeneri: 2])
        ]),
        QuizQuestion(id: "q4", options: [
            QuizOption(id: "a", emoji: "🕯️", weights: [.animaMalinconica: 2, .cercatoreDiBrividi: 1]),
            QuizOption(id: "b", emoji: "💑", weights: [.romanticoIncallito: 2]),
            QuizOption(id: "c", emoji: "🎉", weights: [.avventurieroCurioso: 2]),
            QuizOption(id: "d", emoji: "👨‍👩‍👧", weights: [.sognatoreNostalgico: 2])
        ]),
        QuizQuestion(id: "q5", options: [
            QuizOption(id: "a", emoji: "🎶", weights: [.sognatoreNostalgico: 2, .animaMalinconica: 1]),
            QuizOption(id: "b", emoji: "⚡", weights: [.avventurieroCurioso: 2, .cercatoreDiBrividi: 1]),
            QuizOption(id: "c", emoji: "💭", weights: [.animaMalinconica: 2, .esploratoreDiGeneri: 1]),
            QuizOption(id: "d", emoji: "🏰", weights: [.sognatoreNostalgico: 2])
        ]),
        QuizQuestion(id: "q6", options: [
            QuizOption(id: "a", emoji: "🐉", weights: [.sognatoreNostalgico: 2]),
            QuizOption(id: "b", emoji: "🏚️", weights: [.cercatoreDiBrividi: 2]),
            QuizOption(id: "c", emoji: "🌅", weights: [.romanticoIncallito: 2]),
            QuizOption(id: "d", emoji: "🎞️", weights: [.esploratoreDiGeneri: 2, .animaMalinconica: 1])
        ])
    ]
}
