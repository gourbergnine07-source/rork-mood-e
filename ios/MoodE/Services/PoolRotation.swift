//
//  PoolRotation.swift
//  MoodE
//

import Foundation

/// Widens the discover candidate pool over time: every 14 days the starting
/// page offset used by mood-based discover queries advances, so batches stop
/// drawing only from the first, most popular result pages. The renewal date
/// is persisted and compared on every app open (and on every access, which
/// covers cold starts too). Matching criteria are NEVER touched — only WHICH
/// page of the already-correct category is fetched first.
final class PoolRotation {
    static let shared = PoolRotation()

    private static let offsetKey = "recommendations.pool.offset"
    private static let renewalDateKey = "recommendations.pool.renewalDate"
    /// Renewal cadence: 14 days.
    private static let renewalInterval: TimeInterval = 14 * 24 * 3600
    /// The offset cycles 0…4 and wraps, so pages never drift unbounded.
    private static let cycleLength = 5

    private let defaults = UserDefaults.standard

    private init() {}

    /// Current page offset for discover queries (0 on first install),
    /// renewing it first when the last renewal is 14+ days old.
    var currentOffset: Int {
        renewIfDue()
        return defaults.integer(forKey: Self.offsetKey)
    }

    /// Compares the saved renewal date with today and advances the offset
    /// when due. Called on app open and lazily on every offset access.
    func renewIfDue() {
        guard let last = defaults.object(forKey: Self.renewalDateKey) as? Date else {
            defaults.set(Date(), forKey: Self.renewalDateKey)
            return
        }
        guard Date().timeIntervalSince(last) >= Self.renewalInterval else { return }
        let next = (defaults.integer(forKey: Self.offsetKey) + 1) % Self.cycleLength
        defaults.set(next, forKey: Self.offsetKey)
        defaults.set(Date(), forKey: Self.renewalDateKey)
        AnalyticsService.shared.log("recommendation_pool_renewed", meta: ["offset": String(next)])
    }
}
