//
//  ThemeTrial.swift
//  MoodE
//

import Foundation
import Observation

/// Rewarded-ad reward: every palette and alternate icon unlocked for
/// 24 hours, exactly like a Premium subscription would. Self-expiring and
/// persisted, so it survives relaunches but never outlives its day.
@Observable
final class ThemeTrial {
    static let shared = ThemeTrial()

    private(set) var expiresAt: Date?

    private static let expiresKey = "theme.trial.expiresAt"
    private let defaults = UserDefaults.standard

    private init() {
        let stored = defaults.double(forKey: Self.expiresKey)
        expiresAt = stored > 0 ? Date(timeIntervalSince1970: stored) : nil
    }

    /// True while the trial is running; expired trials self-clean.
    var isActive: Bool {
        guard let expiresAt else { return false }
        if expiresAt <= Date() {
            self.expiresAt = nil
            defaults.removeObject(forKey: Self.expiresKey)
            return false
        }
        return true
    }

    /// Localized "until HH:mm" line for the settings row.
    var expiresLabel: String? {
        guard isActive, let expiresAt else { return nil }
        let formatter = DateFormatter()
        formatter.locale = LocalizationManager.shared.locale
        formatter.timeStyle = .short
        return LF("ads.trial.active", formatter.string(from: expiresAt))
    }

    /// Called from the rewarded callback: unlocks everything for 24 hours.
    func activateFor24Hours() {
        let end = Date().addingTimeInterval(24 * 60 * 60)
        if let current = expiresAt, current > end { return } // no stacking beyond +24h
        expiresAt = end
        defaults.set(end.timeIntervalSince1970, forKey: Self.expiresKey)
        AnalyticsService.shared.log("theme_trial_activated")
    }
}
