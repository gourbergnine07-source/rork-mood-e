//
//  ReviewPrompter.swift
//  MoodE
//

import Foundation

/// Decides when to ask for an App Store rating through Apple's native prompt
/// (`requestReview`), never a link out to the store.
///
/// The prompt only follows a moment of genuine satisfaction — the first of
/// these milestones the user reaches:
/// - a streak of at least 7 consecutive days;
/// - at least 5 movies marked as watched;
/// - the first badge unlocked;
/// - the app used on at least 3 distinct days.
///
/// Each milestone is allowed to ask only once, ever, and never right after a
/// frustrating moment (an error, an empty search, a deletion). On top of that,
/// prompts are capped locally at 3 with months in between — iOS applies its
/// own yearly limit independently, so a call may legitimately show nothing.
enum ReviewPrompter {
    /// The satisfying milestone that opened the door to a prompt.
    enum Trigger: String {
        case streak
        case watched
        case badge
        case sessions
    }

    /// Signals a call site can offer. Anything it doesn't know stays at zero
    /// and simply never matches its milestone.
    struct Signals {
        var streak: Int = 0
        var lifetimeWatched: Int = 0
        var hasUnlockedBadge: Bool = false

        init(streak: Int = 0, lifetimeWatched: Int = 0, hasUnlockedBadge: Bool = false) {
            self.streak = streak
            self.lifetimeWatched = lifetimeWatched
            self.hasUnlockedBadge = hasUnlockedBadge
        }
    }

    // MARK: - Thresholds

    private static let streakDays = 7
    private static let watchedMovies = 5
    private static let sessionDays = 3

    /// Four months between two prompts, three prompts at most.
    private static let cooldown: TimeInterval = 120 * 24 * 60 * 60
    private static let maxPrompts = 3
    /// Quiet window after anything that could have annoyed the user.
    private static let negativeQuietPeriod: TimeInterval = 5 * 60

    // MARK: - Keys

    // The first two keys predate the milestone system: keeping their names
    // preserves the prompt history of users upgrading from an older build.
    private static let lastPromptKey = "review.lastPromptDate"
    private static let promptCountKey = "review.promptCount"
    private static let negativeKey = "review.lastNegativeMoment"
    private static let sessionCountKey = "review.sessionDayCount"
    private static let lastSessionDayKey = "review.lastSessionDay"
    private static func firedKey(_ trigger: Trigger) -> String {
        "review.fired.\(trigger.rawValue)"
    }

    private static var defaults: UserDefaults { .standard }

    // MARK: - Session tracking

    /// Counts the current launch as app usage, once per calendar day.
    static func recordSession() {
        let today = dayKey(for: Date())
        guard defaults.string(forKey: lastSessionDayKey) != today else { return }
        defaults.set(today, forKey: lastSessionDayKey)
        defaults.set(defaults.integer(forKey: sessionCountKey) + 1, forKey: sessionCountKey)
    }

    /// Distinct days the app has been opened on.
    static var distinctSessionDays: Int {
        defaults.integer(forKey: sessionCountKey)
    }

    // MARK: - Negative moments

    /// Marks a frustrating moment (failed request, empty result, deletion):
    /// no rating prompt for a few minutes, whatever milestone is reached.
    static func noteNegativeMoment() {
        defaults.set(Date(), forKey: negativeKey)
    }

    private static var isInQuietPeriod: Bool {
        guard let last = defaults.object(forKey: negativeKey) as? Date else { return false }
        return Date().timeIntervalSince(last) < negativeQuietPeriod
    }

    // MARK: - Decision

    /// Returns true — and records the prompt — when the caller should show the
    /// native rating request. Call it right after a positive action only.
    static func shouldPrompt(_ signals: Signals) -> Bool {
        guard !isInQuietPeriod else { return false }
        guard defaults.integer(forKey: promptCountKey) < maxPrompts else { return false }

        if let last = defaults.object(forKey: lastPromptKey) as? Date,
           Date().timeIntervalSince(last) < cooldown {
            return false
        }

        guard let trigger = firstEligibleTrigger(signals) else { return false }

        defaults.set(true, forKey: firedKey(trigger))
        defaults.set(Date(), forKey: lastPromptKey)
        defaults.set(defaults.integer(forKey: promptCountKey) + 1, forKey: promptCountKey)
        AnalyticsService.shared.log("review_prompt_shown", meta: ["trigger": trigger.rawValue])
        return true
    }

    /// First milestone that is both reached and never used before.
    private static func firstEligibleTrigger(_ signals: Signals) -> Trigger? {
        let reached: [(Trigger, Bool)] = [
            (.streak, signals.streak >= streakDays),
            (.watched, signals.lifetimeWatched >= watchedMovies),
            (.badge, signals.hasUnlockedBadge),
            (.sessions, distinctSessionDays >= sessionDays)
        ]
        return reached.first { trigger, isReached in
            isReached && !defaults.bool(forKey: firedKey(trigger))
        }?.0
    }

    // MARK: - Helpers

    private static func dayKey(for date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }
}
