//
//  DiscoveryPath.swift
//  MoodE
//

import SwiftUI

/// The exact mood → goal → era combination that produced a recommendation,
/// stored alongside a movie the user saved from the results screen.
///
/// Raw values are persisted (not localized labels) so the path is rendered
/// in the language active at reading time. It is purely descriptive data:
/// the recommendation engine and the "already shown" rotation never read it.
nonisolated struct DiscoveryPath: Codable, Hashable {
    let moodRaw: String
    let goalRaw: String
    /// Eras chosen in step 3, in the same order shown in the recap chips.
    let eraRaws: [String]
    /// When the movie was saved through this path.
    let savedDate: Date

    enum CodingKeys: String, CodingKey {
        case moodRaw = "mood"
        case goalRaw = "goal"
        case eraRaws = "eras"
        case savedDate
    }

    @MainActor
    init(selection: MoodSelection, savedDate: Date = Date()) {
        self.moodRaw = selection.mood.rawValue
        self.goalRaw = selection.goal.rawValue
        self.eraRaws = selection.eras.map(\.rawValue)
        self.savedDate = savedDate
    }
}

/// One localized hop of a discovery path ("😊 Felice"), with its own tint.
struct DiscoveryStep: Identifiable {
    let id: Int
    let emoji: String
    let title: String
    let tint: Color
}

extension DiscoveryPath {
    @MainActor var mood: Mood? { Mood(rawValue: moodRaw) }
    @MainActor var goal: ViewingGoal? { ViewingGoal(rawValue: goalRaw) }
    @MainActor var eras: [MovieEra] { eraRaws.compactMap { MovieEra(rawValue: $0) } }

    /// True when the stored raws still map to existing flow options, i.e.
    /// the path can be rendered. Guards against data from older versions.
    @MainActor var isRenderable: Bool { mood != nil && goal != nil }

    /// Localized hops in flow order: emotion, goal, then every chosen era.
    @MainActor var steps: [DiscoveryStep] {
        var result: [DiscoveryStep] = []
        if let mood {
            result.append(DiscoveryStep(id: 0, emoji: mood.emoji, title: mood.title, tint: mood.tint))
        }
        if let goal {
            result.append(DiscoveryStep(id: 1, emoji: goal.emoji, title: goal.title, tint: goal.tint))
        }
        for (index, era) in eras.enumerated() {
            result.append(
                DiscoveryStep(id: 2 + index, emoji: era.emoji, title: era.title, tint: era.tint)
            )
        }
        return result
    }

    /// Plain "😊 Felice → 💗 Emozionarmi → 🍿 Ultimi 5 anni", for
    /// accessibility labels and share text.
    @MainActor var plainText: String {
        steps.map { "\($0.emoji) \($0.title)" }.joined(separator: " → ")
    }
}
