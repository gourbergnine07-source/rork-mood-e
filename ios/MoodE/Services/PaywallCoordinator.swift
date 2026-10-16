//
//  PaywallCoordinator.swift
//  MoodE
//

import Foundation
import Observation

/// Decides when the paywall may be shown and measures its moments, so the
/// paywall appears only when the user has already seen the app's value —
/// never at launch, at most once a day, with a 3-day silence after two
/// consecutive closes.
///
/// Explicit taps (locked feature, "rimuovi pubblicità", upsell rows) always
/// open the paywall: the user asked for it. The throttling applies to the
/// automatic moments only — the third-recommendation trigger and the
/// day-after banner.
@Observable
final class PaywallCoordinator {
    static let shared = PaywallCoordinator()

    /// Where the paywall was opened from (sent with the analytics events).
    enum Origin: String {
        /// Automatic: the user has just seen their third recommendation.
        case thirdRecommendation = "third_recommendation"
        /// A Premium-locked feature was tapped.
        case lockedFeature = "locked_feature"
        /// "Rimuovi pubblicità" / ads upsell tap.
        case removeAds = "remove_ads"
        /// Discrete Home banner, the day after first use.
        case dayAfterBanner = "day_after_banner"
    }

    private(set) var isPaywallVisible = false

    private let defaults = UserDefaults.standard
    private static let lastShownDayKey = "paywall.lastShownDay"
    private static let consecutiveClosesKey = "paywall.consecutiveCloses"
    private static let cooldownUntilKey = "paywall.cooldownUntil"
    private static let firstUseDayKey = "paywall.firstUseDay"
    private static let dayAfterDoneKey = "paywall.dayAfterBannerDone"

    private init() {
        // First launch: record the day so the day-after banner knows when
        // to appear. Existing installs get their day stamped on first run
        // of this code — acceptable, the banner is a one-time nudge.
        if defaults.string(forKey: Self.firstUseDayKey) == nil {
            defaults.set(Self.today(), forKey: Self.firstUseDayKey)
        }
    }

    // MARK: - Automatic triggers

    /// Third recommendation just seen: the classic "value moment". Automatic
    /// presentation obeys every throttle.
    func requestAutoShow(origin: Origin) -> Bool {
        guard canAutoPresent else { return false }
        noteShown(origin: origin)
        return true
    }

    private var canAutoPresent: Bool {
        guard !PremiumStore.shared.isPremium else { return false }
        guard !isPaywallVisible else { return false }
        guard defaults.double(forKey: Self.cooldownUntilKey) < Date().timeIntervalSince1970 else { return false }
        guard defaults.string(forKey: Self.lastShownDayKey) != Self.today() else { return false }
        return true
    }

    /// True when the one-time "day after first use" Home banner should be
    /// on screen (it never shows on the first day — the user must see the
    /// app's value first).
    var shouldShowDayAfterBanner: Bool {
        !PremiumStore.shared.isPremium
            && !defaults.bool(forKey: Self.dayAfterDoneKey)
            && defaults.string(forKey: Self.firstUseDayKey) != Self.today()
    }

    /// The banner was tapped (paywall opening) or dismissed: never again.
    func finishDayAfterBanner() {
        defaults.set(true, forKey: Self.dayAfterDoneKey)
    }

    // MARK: - Lifecycle tracking

    /// Records that the paywall is on screen. Called for every opening,
    /// explicit or automatic: the once-a-day rule counts any show.
    func noteShown(origin: Origin) {
        isPaywallVisible = true
        defaults.set(Self.today(), forKey: Self.lastShownDayKey)
        AnalyticsService.shared.log("paywall_shown", meta: ["origin": origin.rawValue])
    }

    /// Records a close without subscribing. Two in a row silence the
    /// automatic moments for 3 days.
    func noteDismissed(origin: Origin) {
        guard isPaywallVisible else { return }
        isPaywallVisible = false

        let closes = defaults.integer(forKey: Self.consecutiveClosesKey) + 1
        if closes >= 2 {
            defaults.set(0, forKey: Self.consecutiveClosesKey)
            defaults.set(
                Date().timeIntervalSince1970 + 3 * 24 * 60 * 60,
                forKey: Self.cooldownUntilKey
            )
        } else {
            defaults.set(closes, forKey: Self.consecutiveClosesKey)
        }
        AnalyticsService.shared.log("paywall_closed", meta: ["origin": origin.rawValue])
    }

    /// A subscription (or a trial start) happened: the user is a customer,
    /// the close streak is irrelevant from now on.
    func markConverted() {
        isPaywallVisible = false
        defaults.set(0, forKey: Self.consecutiveClosesKey)
        defaults.removeObject(forKey: Self.cooldownUntilKey)
        finishDayAfterBanner()
    }

    private static func today() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
