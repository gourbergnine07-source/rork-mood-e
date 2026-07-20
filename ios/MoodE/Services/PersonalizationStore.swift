//
//  PersonalizationStore.swift
//  MoodE
//

import SwiftUI
import UIKit
import Observation

/// Alternate app icons unlockable through streaks and milestones.
enum AppIconOption: String, CaseIterable, Identifiable {
    case classic
    case gold
    case halloween
    case cinefilo

    var id: String { rawValue }

    /// Asset-catalog name passed to `setAlternateIconName`; nil = primary icon.
    var alternateIconName: String? {
        switch self {
        case .classic: return nil
        case .gold: return "AppIconGold"
        case .halloween: return "AppIconHalloween"
        case .cinefilo: return "AppIconCinefilo"
        }
    }

    /// Bundled preview image shown in the personalization grid.
    var previewAssetName: String {
        switch self {
        case .classic: return "app_icon_preview"
        case .gold: return "heart_film_strip_gold"
        case .halloween: return "pumpkin_heart_spiral_halloween"
        case .cinefilo: return "alt_icon_cinefilo"
        }
    }

    var emoji: String {
        switch self {
        case .classic: return "🎬"
        case .gold: return "🌟"
        case .halloween: return "🎃"
        case .cinefilo: return "🍿"
        }
    }

    var title: String { L("perso.icon.\(rawValue)") }
    var requirement: String { L("perso.icon.\(rawValue).req") }
}

/// Everything the unlock rules need to know, computed by the caller.
struct UnlockContext {
    let streak: Int
    let bestStreak: Int
    let lifetimeWatched: Int
    let quizCompleted: Bool
    let date: Date
}

/// One newly unlocked reward, queued for the celebration toast.
struct UnlockedReward: Identifiable, Equatable {
    let id = UUID()
    let emoji: String
    let title: String
}

/// Tracks which alternate icons and color palettes the user has earned,
/// persists them locally and applies the selected alternate app icon.
@Observable
final class PersonalizationStore {
    private(set) var unlockedIcons: Set<String>
    private(set) var unlockedPalettes: Set<String>
    private(set) var selectedIcon: AppIconOption
    /// Rewards waiting to be celebrated with the in-app toast.
    private(set) var pendingRewards: [UnlockedReward] = []

    private static let iconsKey = "personalization.unlockedIcons"
    private static let palettesKey = "personalization.unlockedPalettes"
    private static let selectedIconKey = "personalization.selectedIcon"

    /// Palettes gated behind milestones; every other palette is free.
    static let lockedPalettes: [AccentPalette] = [.oro, .aurora, .velluto]

    private let defaults = UserDefaults.standard

    init() {
        let defaults = UserDefaults.standard
        unlockedIcons = Set(defaults.stringArray(forKey: Self.iconsKey) ?? [])
        unlockedPalettes = Set(defaults.stringArray(forKey: Self.palettesKey) ?? [])
        let storedIcon = defaults.string(forKey: Self.selectedIconKey)
        selectedIcon = AppIconOption(rawValue: storedIcon ?? "") ?? .classic
    }

    // MARK: - Queries

    func isUnlocked(_ icon: AppIconOption) -> Bool {
        icon == .classic || unlockedIcons.contains(icon.rawValue)
    }

    func isUnlocked(_ palette: AccentPalette) -> Bool {
        !Self.lockedPalettes.contains(palette) || unlockedPalettes.contains(palette.rawValue)
    }

    /// Localized description of what unlocks a locked palette.
    func requirement(for palette: AccentPalette) -> String {
        L("perso.palette.\(palette.rawValue).req")
    }

    // MARK: - Unlock rules

    /// Re-checks every milestone; newly earned rewards are queued for the toast.
    func evaluate(_ context: UnlockContext) {
        var newRewards: [UnlockedReward] = []

        let iconConditions: [(AppIconOption, Bool)] = [
            (.gold, max(context.streak, context.bestStreak) >= 21),
            (.halloween, Self.isHalloweenPeriod(context.date)),
            (.cinefilo, context.lifetimeWatched >= 40)
        ]
        for (icon, condition) in iconConditions where condition && !unlockedIcons.contains(icon.rawValue) {
            unlockedIcons.insert(icon.rawValue)
            newRewards.append(UnlockedReward(emoji: icon.emoji, title: icon.title))
            AnalyticsService.shared.log("reward_unlocked", meta: ["reward": "icon_\(icon.rawValue)"])
        }

        let paletteConditions: [(AccentPalette, Bool)] = [
            (.oro, context.bestStreak >= 7),
            (.aurora, context.lifetimeWatched >= 20),
            (.velluto, context.quizCompleted)
        ]
        for (palette, condition) in paletteConditions where condition && !unlockedPalettes.contains(palette.rawValue) {
            unlockedPalettes.insert(palette.rawValue)
            newRewards.append(UnlockedReward(emoji: "🎨", title: palette.displayName))
            AnalyticsService.shared.log("reward_unlocked", meta: ["reward": "palette_\(palette.rawValue)"])
        }

        guard !newRewards.isEmpty else { return }
        persist()
        pendingRewards.append(contentsOf: newRewards)
    }

    /// Convenience: builds the context from the shared stores.
    func evaluate(diary: MoodDiary, library: MovieLibrary, planner: MoviePlanner, quizCompleted: Bool) {
        let watchedIds = MovieStatsStore.watchedIds(watched: library.watched, memories: planner.memories)
        evaluate(UnlockContext(
            streak: diary.streak,
            bestStreak: diary.bestStreak,
            lifetimeWatched: max(library.lifetimeWatchedCount, watchedIds.count),
            quizCompleted: quizCompleted,
            date: Date()
        ))
    }

    private static func isHalloweenPeriod(_ date: Date) -> Bool {
        FeaturedCalendar.all.first { $0.id == "halloween" }?.period?.contains(date) == true
    }

    // MARK: - Icon switching

    /// Applies an unlocked alternate icon (or restores the classic one).
    func select(_ icon: AppIconOption) {
        guard isUnlocked(icon), UIApplication.shared.supportsAlternateIcons else { return }
        selectedIcon = icon
        defaults.set(icon.rawValue, forKey: Self.selectedIconKey)
        UIApplication.shared.setAlternateIconName(icon.alternateIconName) { error in
            if let error {
                print("PersonalizationStore: icon switch failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Toast queue

    func dismissReward(_ reward: UnlockedReward) {
        pendingRewards.removeAll { $0.id == reward.id }
    }

    private func persist() {
        defaults.set(Array(unlockedIcons), forKey: Self.iconsKey)
        defaults.set(Array(unlockedPalettes), forKey: Self.palettesKey)
    }
}
