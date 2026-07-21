//
//  ChallengeStore.swift
//  MoodE
//

import Foundation
import Observation

/// Remembers which monthly challenges were completed (month keys like
/// "2026-07") and feeds the total into the badge system.
@Observable
final class ChallengeStore {
    static let shared = ChallengeStore()

    /// UserDefaults key holding the completed month keys ([String]).
    static let completedKey = "challenges.completedMonths"

    private(set) var completedMonths: Set<String>

    private init() {
        completedMonths = Set(UserDefaults.standard.stringArray(forKey: Self.completedKey) ?? [])
    }

    func isCompleted(_ monthKey: String) -> Bool {
        completedMonths.contains(monthKey)
    }

    /// Marks the month's challenge as done (idempotent) and logs the event.
    func markCompleted(_ monthKey: String) {
        guard !completedMonths.contains(monthKey) else { return }
        completedMonths.insert(monthKey)
        UserDefaults.standard.set(Array(completedMonths), forKey: Self.completedKey)
        AnalyticsService.shared.log("challenge_completed", meta: ["month": monthKey])
    }

    /// Lifetime completed count, read directly from storage so
    /// `MoodDiary.stats` can use it without holding a reference.
    static var completedCount: Int {
        UserDefaults.standard.stringArray(forKey: completedKey)?.count ?? 0
    }
}
