//
//  QuizCatalog.swift
//  MoodE
//

import SwiftUI

/// Every quiz shipped with the app. Adding a quiz means adding a definition
/// here plus its strings in the four localization tables — no screen changes:
/// hub, player, result and history are all driven by these definitions.
enum QuizCatalog {
    static var all: [QuizDefinition] {
        [spectator, decade, secretGenre, tonight, cinephile]
    }

    static func definition(id: String) -> QuizDefinition? {
        all.first { $0.id == id }
    }

    static func definition(_ kind: QuizKind) -> QuizDefinition {
        definition(id: kind.rawValue) ?? spectator
    }

    // MARK: - Che spettatore sei?

    /// The original quiz: six questions, six cinematic personalities. Its
    /// outcome is the only one that also refines the recommendations ranking.
    static let spectator = QuizDefinition(
        kind: .spectator,
        keyPrefix: "quiz",
        questions: [
            QuizQuestion(id: "q1", options: [
                QuizOption(id: "a", emoji: "🛋️", weights: ["sognatoreNostalgico": 2, "romanticoIncallito": 1]),
                QuizOption(id: "b", emoji: "🎬", weights: ["esploratoreDiGeneri": 2, "avventurieroCurioso": 1]),
                QuizOption(id: "c", emoji: "👻", weights: ["cercatoreDiBrividi": 2]),
                QuizOption(id: "d", emoji: "😢", weights: ["animaMalinconica": 2])
            ]),
            QuizQuestion(id: "q2", options: [
                QuizOption(id: "a", emoji: "🥹", weights: ["romanticoIncallito": 2, "animaMalinconica": 1]),
                QuizOption(id: "b", emoji: "🤯", weights: ["cercatoreDiBrividi": 2, "esploratoreDiGeneri": 1]),
                QuizOption(id: "c", emoji: "🌫️", weights: ["animaMalinconica": 2, "esploratoreDiGeneri": 1]),
                QuizOption(id: "d", emoji: "🏆", weights: ["avventurieroCurioso": 2])
            ]),
            QuizQuestion(id: "q3", options: [
                QuizOption(id: "a", emoji: "🙈", weights: ["romanticoIncallito": 1, "sognatoreNostalgico": 1]),
                QuizOption(id: "b", emoji: "💔", weights: ["avventurieroCurioso": 1, "cercatoreDiBrividi": 1]),
                QuizOption(id: "c", emoji: "📚", weights: ["sognatoreNostalgico": 1, "avventurieroCurioso": 1]),
                QuizOption(id: "d", emoji: "🤷", weights: ["esploratoreDiGeneri": 2])
            ]),
            QuizQuestion(id: "q4", options: [
                QuizOption(id: "a", emoji: "🕯️", weights: ["animaMalinconica": 2, "cercatoreDiBrividi": 1]),
                QuizOption(id: "b", emoji: "💑", weights: ["romanticoIncallito": 2]),
                QuizOption(id: "c", emoji: "🎉", weights: ["avventurieroCurioso": 2]),
                QuizOption(id: "d", emoji: "👨‍👩‍👧", weights: ["sognatoreNostalgico": 2])
            ]),
            QuizQuestion(id: "q5", options: [
                QuizOption(id: "a", emoji: "🎶", weights: ["sognatoreNostalgico": 2, "animaMalinconica": 1]),
                QuizOption(id: "b", emoji: "⚡", weights: ["avventurieroCurioso": 2, "cercatoreDiBrividi": 1]),
                QuizOption(id: "c", emoji: "💭", weights: ["animaMalinconica": 2, "esploratoreDiGeneri": 1]),
                QuizOption(id: "d", emoji: "🏰", weights: ["sognatoreNostalgico": 2])
            ]),
            QuizQuestion(id: "q6", options: [
                QuizOption(id: "a", emoji: "🐉", weights: ["sognatoreNostalgico": 2]),
                QuizOption(id: "b", emoji: "🏚️", weights: ["cercatoreDiBrividi": 2]),
                QuizOption(id: "c", emoji: "🌅", weights: ["romanticoIncallito": 2]),
                QuizOption(id: "d", emoji: "🎞️", weights: ["esploratoreDiGeneri": 2, "animaMalinconica": 1])
            ])
        ],
        outcomes: SpectatorProfile.allCases.map { profile in
            QuizOutcome(
                id: profile.rawValue,
                keyBase: "quiz.profile.\(profile.rawValue)",
                emoji: profile.emoji,
                icon: profile.icon,
                gradient: profile.gradient
            )
        },
        scoring: .weighted
    )

    // MARK: - Che decade cinematografica sei?

    static let decade = QuizDefinition(
        kind: .decade,
        keyPrefix: "quizdec",
        questions: [
            QuizQuestion(id: "q1", options: [
                QuizOption(id: "a", emoji: "🗣️", weights: ["anni70": 2, "anni80": 1]),
                QuizOption(id: "b", emoji: "📦", weights: ["anni80": 2, "anni90": 1]),
                QuizOption(id: "c", emoji: "⭐", weights: ["anni2010": 2, "anni2000": 1]),
                QuizOption(id: "d", emoji: "🤖", weights: ["oggi": 2])
            ]),
            QuizQuestion(id: "q2", options: [
                QuizOption(id: "a", emoji: "🎻", weights: ["anni70": 2]),
                QuizOption(id: "b", emoji: "🎹", weights: ["anni80": 2]),
                QuizOption(id: "c", emoji: "🎸", weights: ["anni90": 2]),
                QuizOption(id: "d", emoji: "🎧", weights: ["anni2010": 2, "anni2000": 1])
            ]),
            QuizQuestion(id: "q3", options: [
                QuizOption(id: "a", emoji: "🛠️", weights: ["anni70": 2, "anni80": 1]),
                QuizOption(id: "b", emoji: "🦖", weights: ["anni90": 2]),
                QuizOption(id: "c", emoji: "🟩", weights: ["anni2000": 2]),
                QuizOption(id: "d", emoji: "🫥", weights: ["oggi": 2])
            ]),
            QuizQuestion(id: "q4", options: [
                QuizOption(id: "a", emoji: "🚬", weights: ["anni70": 2]),
                QuizOption(id: "b", emoji: "💪", weights: ["anni80": 2]),
                QuizOption(id: "c", emoji: "🎒", weights: ["anni90": 2, "anni2000": 1]),
                QuizOption(id: "d", emoji: "🧑‍🤝‍🧑", weights: ["anni2010": 2, "oggi": 1])
            ]),
            QuizQuestion(id: "q5", options: [
                QuizOption(id: "a", emoji: "🎞️", weights: ["anni70": 2]),
                QuizOption(id: "b", emoji: "📼", weights: ["anni90": 2, "anni80": 1]),
                QuizOption(id: "c", emoji: "💿", weights: ["anni2000": 2]),
                QuizOption(id: "d", emoji: "📱", weights: ["oggi": 2, "anni2010": 1])
            ]),
            QuizQuestion(id: "q6", options: [
                QuizOption(id: "a", emoji: "⏳", weights: ["anni70": 2]),
                QuizOption(id: "b", emoji: "⚡", weights: ["anni80": 2]),
                QuizOption(id: "c", emoji: "🕰️", weights: ["anni2000": 2, "anni90": 1]),
                QuizOption(id: "d", emoji: "🔗", weights: ["oggi": 2])
            ])
        ],
        outcomes: [
            QuizOutcome(
                id: "anni70",
                keyBase: "quizdec.res.anni70",
                emoji: "🎞️",
                icon: "film.stack",
                gradient: [Color(red: 0.62, green: 0.36, blue: 0.16), Color(red: 0.30, green: 0.16, blue: 0.10)]
            ),
            QuizOutcome(
                id: "anni80",
                keyBase: "quizdec.res.anni80",
                emoji: "🕹️",
                icon: "gamecontroller.fill",
                gradient: [Color(red: 0.85, green: 0.24, blue: 0.55), Color(red: 0.24, green: 0.16, blue: 0.52)]
            ),
            QuizOutcome(
                id: "anni90",
                keyBase: "quizdec.res.anni90",
                emoji: "📼",
                icon: "recordingtape",
                gradient: [Color(red: 0.20, green: 0.52, blue: 0.62), Color(red: 0.10, green: 0.22, blue: 0.36)]
            ),
            QuizOutcome(
                id: "anni2000",
                keyBase: "quizdec.res.anni2000",
                emoji: "💿",
                icon: "opticaldisc.fill",
                gradient: [Color(red: 0.36, green: 0.42, blue: 0.78), Color(red: 0.14, green: 0.16, blue: 0.34)]
            ),
            QuizOutcome(
                id: "anni2010",
                keyBase: "quizdec.res.anni2010",
                emoji: "📱",
                icon: "play.tv.fill",
                gradient: [Color(red: 0.78, green: 0.35, blue: 0.60), Color(red: 0.30, green: 0.14, blue: 0.34)]
            ),
            QuizOutcome(
                id: "oggi",
                keyBase: "quizdec.res.oggi",
                emoji: "✨",
                icon: "sparkles.tv.fill",
                gradient: [Color(red: 0.16, green: 0.56, blue: 0.52), Color(red: 0.06, green: 0.22, blue: 0.26)]
            )
        ],
        scoring: .weighted
    )

    // MARK: - Qual è il tuo genere segreto?

    static let secretGenre = QuizDefinition(
        kind: .secretGenre,
        keyPrefix: "quizgen",
        questions: [
            QuizQuestion(id: "q1", options: [
                QuizOption(id: "a", emoji: "🎭", weights: ["noir": 2, "commediaAmara": 1]),
                QuizOption(id: "b", emoji: "🌌", weights: ["fantascienza": 2, "documentario": 1]),
                QuizOption(id: "c", emoji: "🎨", weights: ["animazione": 2]),
                QuizOption(id: "d", emoji: "📰", weights: ["documentario": 2])
            ]),
            QuizQuestion(id: "q2", options: [
                QuizOption(id: "a", emoji: "🌓", weights: ["noir": 2, "horrorArt": 1]),
                QuizOption(id: "b", emoji: "🔇", weights: ["horrorArt": 2, "fantascienza": 1]),
                QuizOption(id: "c", emoji: "🖌️", weights: ["animazione": 2]),
                QuizOption(id: "d", emoji: "🗯️", weights: ["commediaAmara": 2])
            ]),
            QuizQuestion(id: "q3", options: [
                QuizOption(id: "a", emoji: "🪨", weights: ["commediaAmara": 2, "noir": 1]),
                QuizOption(id: "b", emoji: "🌀", weights: ["fantascienza": 2]),
                QuizOption(id: "c", emoji: "🫣", weights: ["horrorArt": 2, "animazione": 1]),
                QuizOption(id: "d", emoji: "🧾", weights: ["documentario": 2])
            ]),
            QuizQuestion(id: "q4", options: [
                QuizOption(id: "a", emoji: "🕶️", weights: ["noir": 2]),
                QuizOption(id: "b", emoji: "🍸", weights: ["commediaAmara": 2]),
                QuizOption(id: "c", emoji: "🕯️", weights: ["horrorArt": 2]),
                QuizOption(id: "d", emoji: "🔭", weights: ["documentario": 2, "fantascienza": 1])
            ]),
            QuizQuestion(id: "q5", options: [
                QuizOption(id: "a", emoji: "🌃", weights: ["noir": 2, "horrorArt": 1]),
                QuizOption(id: "b", emoji: "🎪", weights: ["documentario": 2, "animazione": 1]),
                QuizOption(id: "c", emoji: "🎧", weights: ["fantascienza": 2, "horrorArt": 1]),
                QuizOption(id: "d", emoji: "😏", weights: ["commediaAmara": 2])
            ])
        ],
        outcomes: [
            QuizOutcome(
                id: "noir",
                keyBase: "quizgen.res.noir",
                emoji: "🚬",
                icon: "moon.haze.fill",
                gradient: [Color(red: 0.20, green: 0.22, blue: 0.28), Color(red: 0.05, green: 0.06, blue: 0.09)]
            ),
            QuizOutcome(
                id: "fantascienza",
                keyBase: "quizgen.res.fantascienza",
                emoji: "🛰️",
                icon: "atom",
                gradient: [Color(red: 0.16, green: 0.40, blue: 0.68), Color(red: 0.06, green: 0.12, blue: 0.30)]
            ),
            QuizOutcome(
                id: "animazione",
                keyBase: "quizgen.res.animazione",
                emoji: "🎨",
                icon: "paintbrush.pointed.fill",
                gradient: [Color(red: 0.94, green: 0.52, blue: 0.24), Color(red: 0.66, green: 0.20, blue: 0.46)]
            ),
            QuizOutcome(
                id: "documentario",
                keyBase: "quizgen.res.documentario",
                emoji: "🔭",
                icon: "binoculars.fill",
                gradient: [Color(red: 0.18, green: 0.52, blue: 0.44), Color(red: 0.07, green: 0.22, blue: 0.22)]
            ),
            QuizOutcome(
                id: "horrorArt",
                keyBase: "quizgen.res.horrorArt",
                emoji: "🕯️",
                icon: "flame.fill",
                gradient: [Color(red: 0.42, green: 0.12, blue: 0.24), Color(red: 0.10, green: 0.05, blue: 0.12)]
            ),
            QuizOutcome(
                id: "commediaAmara",
                keyBase: "quizgen.res.commediaAmara",
                emoji: "🍸",
                icon: "theatermask.and.paintbrush.fill",
                gradient: [Color(red: 0.78, green: 0.58, blue: 0.20), Color(red: 0.34, green: 0.20, blue: 0.28)]
            )
        ],
        scoring: .weighted
    )

    // MARK: - Che serata guardi stasera?

    /// The short, light one: four questions and an outcome that doubles as an
    /// immediate suggestion (its `advice` opens the results screen).
    static let tonight = QuizDefinition(
        kind: .tonight,
        keyPrefix: "quiznight",
        questions: [
            QuizQuestion(id: "q1", options: [
                QuizOption(id: "a", emoji: "🔋", weights: ["comfort": 2]),
                QuizOption(id: "b", emoji: "⚡", weights: ["adrenalina": 2]),
                QuizOption(id: "c", emoji: "🫂", weights: ["lacrime": 2]),
                QuizOption(id: "d", emoji: "🧭", weights: ["scoperta": 2])
            ]),
            QuizQuestion(id: "q2", options: [
                QuizOption(id: "a", emoji: "🛏️", weights: ["comfort": 2, "lacrime": 1]),
                QuizOption(id: "b", emoji: "🎉", weights: ["risate": 2, "adrenalina": 1]),
                QuizOption(id: "c", emoji: "🕯️", weights: ["lacrime": 2, "comfort": 1]),
                QuizOption(id: "d", emoji: "🤝", weights: ["scoperta": 2])
            ]),
            QuizQuestion(id: "q3", options: [
                QuizOption(id: "a", emoji: "⏱️", weights: ["risate": 2, "comfort": 1]),
                QuizOption(id: "b", emoji: "🌙", weights: ["adrenalina": 2, "scoperta": 1]),
                QuizOption(id: "c", emoji: "🕰️", weights: ["lacrime": 2]),
                QuizOption(id: "d", emoji: "♾️", weights: ["scoperta": 2, "comfort": 1])
            ]),
            QuizQuestion(id: "q4", options: [
                QuizOption(id: "a", emoji: "😴", weights: ["comfort": 2]),
                QuizOption(id: "b", emoji: "💓", weights: ["adrenalina": 2]),
                QuizOption(id: "c", emoji: "💧", weights: ["lacrime": 2]),
                QuizOption(id: "d", emoji: "🗣️", weights: ["scoperta": 2, "risate": 1])
            ])
        ],
        outcomes: [
            QuizOutcome(
                id: "comfort",
                keyBase: "quiznight.res.comfort",
                emoji: "🛋️",
                icon: "sofa.fill",
                gradient: [Color(red: 0.32, green: 0.44, blue: 0.52), Color(red: 0.12, green: 0.18, blue: 0.26)],
                advice: MoodSelection(mood: .stressato, goal: .rilassarmi, era: .noPreference)
            ),
            QuizOutcome(
                id: "adrenalina",
                keyBase: "quiznight.res.adrenalina",
                emoji: "⚡",
                icon: "bolt.fill",
                gradient: [Color(red: 0.72, green: 0.18, blue: 0.30), Color(red: 0.22, green: 0.08, blue: 0.20)],
                advice: MoodSelection(mood: .curioso, goal: .paura, era: .noPreference)
            ),
            QuizOutcome(
                id: "lacrime",
                keyBase: "quiznight.res.lacrime",
                emoji: "💧",
                icon: "drop.fill",
                gradient: [Color(red: 0.28, green: 0.42, blue: 0.72), Color(red: 0.10, green: 0.16, blue: 0.32)],
                advice: MoodSelection(mood: .malinconico, goal: .piangere, era: .noPreference)
            ),
            QuizOutcome(
                id: "risate",
                keyBase: "quiznight.res.risate",
                emoji: "😂",
                icon: "face.smiling.inverse",
                gradient: [Color(red: 0.94, green: 0.66, blue: 0.16), Color(red: 0.60, green: 0.30, blue: 0.10)],
                advice: MoodSelection(mood: .felice, goal: .ridere, era: .noPreference)
            ),
            QuizOutcome(
                id: "scoperta",
                keyBase: "quiznight.res.scoperta",
                emoji: "🧭",
                icon: "safari.fill",
                gradient: [Color(red: 0.18, green: 0.50, blue: 0.50), Color(red: 0.07, green: 0.20, blue: 0.28)],
                advice: MoodSelection(mood: .curioso, goal: .riflettere, era: .noPreference)
            )
        ],
        scoring: .weighted
    )

    // MARK: - Quanto sei cinefilo?

    /// Level-based quiz: every answer is worth 0 to 3 points and the total
    /// lands on a ladder from casual viewer to die-hard cinephile.
    static let cinephile = QuizDefinition(
        kind: .cinephile,
        keyPrefix: "quizcine",
        questions: [
            QuizQuestion(id: "q1", options: [
                QuizOption(id: "a", emoji: "🌙", points: 0),
                QuizOption(id: "b", emoji: "🍿", points: 1),
                QuizOption(id: "c", emoji: "📅", points: 2),
                QuizOption(id: "d", emoji: "🔥", points: 3)
            ]),
            QuizQuestion(id: "q2", options: [
                QuizOption(id: "a", emoji: "🤷", points: 0),
                QuizOption(id: "b", emoji: "⭐", points: 1),
                QuizOption(id: "c", emoji: "🎯", points: 2),
                QuizOption(id: "d", emoji: "✂️", points: 3)
            ]),
            QuizQuestion(id: "q3", options: [
                QuizOption(id: "a", emoji: "⏭️", points: 0),
                QuizOption(id: "b", emoji: "😌", points: 1),
                QuizOption(id: "c", emoji: "🎬", points: 2),
                QuizOption(id: "d", emoji: "📜", points: 3)
            ]),
            QuizQuestion(id: "q4", options: [
                QuizOption(id: "a", emoji: "🗣️", points: 0),
                QuizOption(id: "b", emoji: "🔀", points: 1),
                QuizOption(id: "c", emoji: "💬", points: 2),
                QuizOption(id: "d", emoji: "🧠", points: 3)
            ]),
            QuizQuestion(id: "q5", options: [
                QuizOption(id: "a", emoji: "🙈", points: 0),
                QuizOption(id: "b", emoji: "🏆", points: 1),
                QuizOption(id: "c", emoji: "📝", points: 2),
                QuizOption(id: "d", emoji: "🦁", points: 3)
            ]),
            QuizQuestion(id: "q6", options: [
                QuizOption(id: "a", emoji: "🚫", points: 0),
                QuizOption(id: "b", emoji: "🤔", points: 1),
                QuizOption(id: "c", emoji: "🩶", points: 2),
                QuizOption(id: "d", emoji: "🖤", points: 3)
            ])
        ],
        outcomes: [
            QuizOutcome(
                id: "occasionale",
                keyBase: "quizcine.res.occasionale",
                emoji: "🍿",
                icon: "popcorn.fill",
                gradient: [Color(red: 0.36, green: 0.46, blue: 0.54), Color(red: 0.14, green: 0.20, blue: 0.26)],
                minPoints: 0
            ),
            QuizOutcome(
                id: "appassionato",
                keyBase: "quizcine.res.appassionato",
                emoji: "🎟️",
                icon: "ticket.fill",
                gradient: [Color(red: 0.24, green: 0.54, blue: 0.50), Color(red: 0.08, green: 0.22, blue: 0.24)],
                minPoints: 5
            ),
            QuizOutcome(
                id: "esperto",
                keyBase: "quizcine.res.esperto",
                emoji: "🎥",
                icon: "camera.fill",
                gradient: [Color(red: 0.34, green: 0.38, blue: 0.74), Color(red: 0.12, green: 0.14, blue: 0.32)],
                minPoints: 9
            ),
            QuizOutcome(
                id: "divoratore",
                keyBase: "quizcine.res.divoratore",
                emoji: "🎬",
                icon: "film.fill",
                gradient: [Color(red: 0.66, green: 0.28, blue: 0.52), Color(red: 0.24, green: 0.10, blue: 0.28)],
                minPoints: 13
            ),
            QuizOutcome(
                id: "incallito",
                keyBase: "quizcine.res.incallito",
                emoji: "🏆",
                icon: "trophy.fill",
                gradient: [Color(red: 0.84, green: 0.62, blue: 0.18), Color(red: 0.42, green: 0.22, blue: 0.08)],
                minPoints: 16
            )
        ],
        scoring: .points
    )
}
