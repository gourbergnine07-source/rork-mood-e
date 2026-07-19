//
//  ReviewPrompter.swift
//  MoodE
//

import Foundation

/// Decides when to ask for an App Store rating. The prompt appears only
/// right after the user marks a movie as watched (a satisfying moment),
/// at most once every 4 months and never more than 3 times in total —
/// well within Apple's yearly system limit.
enum ReviewPrompter {
    private static let lastPromptKey = "review.lastPromptDate"
    private static let promptCountKey = "review.promptCount"

    /// At least this many movies watched before ever asking.
    private static let minimumWatched = 2
    /// Four months between prompts.
    private static let cooldown: TimeInterval = 120 * 24 * 60 * 60
    private static let maxPrompts = 3

    /// Returns true (and records the prompt) when it's a good moment
    /// to ask for a rating.
    static func shouldPrompt(lifetimeWatched: Int) -> Bool {
        guard lifetimeWatched >= minimumWatched else { return false }

        let defaults = UserDefaults.standard
        guard defaults.integer(forKey: promptCountKey) < maxPrompts else { return false }

        if let last = defaults.object(forKey: lastPromptKey) as? Date,
           Date().timeIntervalSince(last) < cooldown {
            return false
        }

        defaults.set(Date(), forKey: lastPromptKey)
        defaults.set(defaults.integer(forKey: promptCountKey) + 1, forKey: promptCountKey)
        return true
    }
}
