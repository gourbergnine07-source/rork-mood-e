//
//  MoodIntents.swift
//  MoodE
//
//  App Intents: Siri / Shortcuts entry point ("what should I watch?").
//

import AppIntents
import Foundation

/// The 12 Mood-E emotions exposed to Siri and the Shortcuts app.
/// Raw values match `Mood` so the two enums convert 1:1.
nonisolated enum MoodOption: String, AppEnum {
    case felice, triste, stressato, annoiato, innamorato, nostalgico
    case arrabbiato, motivato, malinconico, spensierato, curioso, impaurito

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Mood")

    static let caseDisplayRepresentations: [MoodOption: DisplayRepresentation] = [
        .felice: "😊 Happy",
        .triste: "😢 Sad",
        .stressato: "😰 Stressed",
        .annoiato: "🥱 Bored",
        .innamorato: "😍 In love",
        .nostalgico: "🕰️ Nostalgic",
        .arrabbiato: "😡 Angry",
        .motivato: "💪 Motivated",
        .malinconico: "🌧️ Melancholic",
        .spensierato: "🦋 Carefree",
        .curioso: "🤔 Curious",
        .impaurito: "😨 Scared"
    ]
}

/// Siri / Shortcuts command: asks how the user feels (if not said already),
/// then opens Mood-E straight on the results screen with a ready proposal
/// (quick-pick: goal and era derived from the mood).
nonisolated struct WhatToWatchIntent: AppIntent {
    static let title: LocalizedStringResource = "What to Watch Tonight"
    static let description = IntentDescription(
        "Tell Mood-E how you feel and get a movie proposal right away."
    )
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Mood", requestValueDialog: "How are you feeling right now?")
    var mood: MoodOption

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        IntentRelay.launch(moodRaw: mood.rawValue)
        return .result(dialog: "Here's a movie idea for you 🎬")
    }
}

/// Bridges App Intents to the running SwiftUI scene: stores the requested
/// mood (consumed at cold start) and pings the live scene (warm start).
@MainActor
enum IntentRelay {
    private static let pendingMoodKey = "intent.pendingMood"

    static func launch(moodRaw: String) {
        UserDefaults.standard.set(moodRaw, forKey: pendingMoodKey)
        AnalyticsService.shared.log("siri_intent_used", meta: ["mood": moodRaw])
        NotificationCenter.default.post(
            name: NotificationRoute.notificationName,
            object: NotificationRoute.forecast,
            userInfo: ["mood": moodRaw]
        )
    }

    /// Returns and clears the pending mood, if any (cold-start path).
    static func consumePendingMood() -> Mood? {
        guard let raw = UserDefaults.standard.string(forKey: pendingMoodKey) else { return nil }
        UserDefaults.standard.removeObject(forKey: pendingMoodKey)
        return Mood(rawValue: raw)
    }
}

/// Makes the command discoverable by Siri without any user setup.
nonisolated struct MoodEShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: WhatToWatchIntent(),
            phrases: [
                "What should I watch on \(.applicationName)",
                "Ask \(.applicationName) what to watch tonight",
                "Find me a movie on \(.applicationName)"
            ],
            shortTitle: "What to Watch",
            systemImageName: "movieclapper.fill"
        )
    }

    static let shortcutTileColor: ShortcutTileColor = .orange
}
