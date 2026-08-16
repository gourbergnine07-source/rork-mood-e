//
//  AppUpdateService.swift
//  MoodE
//

import Foundation
import Observation
import Supabase

/// Row of `app_release_config`: the release gate edited remotely (Supabase)
/// every time a new build goes live on the App Store. Clients can only read
/// it, so turning the update notice on or off never needs a new build.
nonisolated struct ReleaseConfig: Codable, Sendable {
    let latestVersion: String
    let minimumRequiredVersion: String
    /// Optional per-language one-liner shown in the banner instead of the
    /// default copy, keyed by language code ("it", "en", …).
    let notes: [String: String]?

    enum CodingKeys: String, CodingKey {
        case latestVersion = "latest_version"
        case minimumRequiredVersion = "minimum_required_version"
        case notes
    }
}

/// Compares the installed version with the one published remotely and decides
/// whether to invite the user to update (discreet banner) or to require it
/// (blocking screen, for breaking technical changes only).
///
/// The whole behaviour is driven by `app_release_config` on the backend:
/// bumping `latest_version` there is enough to start showing the notice, and
/// lowering it again hides it — no App Store submission involved.
@Observable
final class AppUpdateService {
    static let shared = AppUpdateService()

    /// How the installed version compares to the published one.
    enum Status: Equatable {
        /// No config read yet (first launch, offline with empty cache).
        case unknown
        case upToDate
        /// A newer version exists: discreet, dismissible banner.
        case recommended
        /// Installed version is below `minimum_required_version`: blocking.
        case required
    }

    private(set) var status: Status = .unknown
    /// Version published on the App Store, as declared remotely.
    private(set) var latestVersion: String = ""
    /// Whether the Home banner should be on screen right now.
    private(set) var isBannerVisible: Bool = false

    /// True while the app must not be usable until the user updates.
    var isBlocking: Bool { status == .required }

    /// Version of this install, e.g. "1.5".
    let installedVersion: String = {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }()

    /// Direct link to the Mood-E product page (not a store search).
    let appStoreURL: URL = URL(string: "https://apps.apple.com/app/id6792271949")!

    private var notes: [String: String]?
    private var minimumVersion: String = ""
    private var lastFetch: Date?

    /// Remote config is re-read at most this often per app session cycle.
    private static let fetchInterval: TimeInterval = 4 * 60 * 60

    private static let cachedLatestKey = "update.cachedLatest"
    private static let cachedMinimumKey = "update.cachedMinimum"
    private static let cachedNotesKey = "update.cachedNotes"
    private static let bannerDayKey = "update.bannerLastDay"
    private static let bannerVersionKey = "update.bannerLastVersion"

    private let defaults = UserDefaults.standard

    private init() {
        latestVersion = defaults.string(forKey: Self.cachedLatestKey) ?? ""
        minimumVersion = defaults.string(forKey: Self.cachedMinimumKey) ?? ""
        if let data = defaults.data(forKey: Self.cachedNotesKey) {
            notes = try? JSONDecoder().decode([String: String].self, from: data)
        }
    }

    // MARK: - API

    /// Reads the remote config and updates `status` / `isBannerVisible`.
    /// Safe to call on every launch and on every return to foreground: the
    /// network read is throttled, the decision is always re-evaluated so a
    /// cached blocking state survives being offline.
    func check() async {
        evaluate()

        if let last = lastFetch, Date().timeIntervalSince(last) < Self.fetchInterval {
            return
        }

        guard let config = await fetchConfig() else { return }
        lastFetch = Date()
        apply(config)
        evaluate()
    }

    /// Hides the banner for today. It can come back at the next launch on a
    /// following day, or straight away if a newer version is published.
    func dismissBanner() {
        guard isBannerVisible else { return }
        isBannerVisible = false
        AnalyticsService.shared.log("update_banner_dismissed", meta: [
            "installed": installedVersion,
            "latest": latestVersion
        ])
    }

    /// Localized one-liner from the remote config, when provided.
    var remoteNote: String? {
        guard let notes else { return nil }
        let text = notes[L10nStore.currentCode] ?? notes["en"]
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return text
    }

    /// Records the tap that sends the user to the App Store.
    func logUpdateTap(blocking: Bool) {
        AnalyticsService.shared.log("update_cta_tapped", meta: [
            "installed": installedVersion,
            "latest": latestVersion,
            "blocking": blocking ? "1" : "0"
        ])
    }

    // MARK: - Internals

    private func fetchConfig() async -> ReleaseConfig? {
        do {
            let config: ReleaseConfig = try await SupabaseService.client
                .from("app_release_config")
                .select("latest_version,minimum_required_version,notes")
                .eq("platform", value: "ios")
                .single()
                .execute()
                .value
            return config
        } catch {
            // Never surfaced to the user: a missed check simply means no
            // notice this time, the app keeps working normally.
            print("[AppUpdate] config fetch failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func apply(_ config: ReleaseConfig) {
        latestVersion = config.latestVersion.trimmingCharacters(in: .whitespaces)
        minimumVersion = config.minimumRequiredVersion.trimmingCharacters(in: .whitespaces)
        notes = config.notes

        defaults.set(latestVersion, forKey: Self.cachedLatestKey)
        defaults.set(minimumVersion, forKey: Self.cachedMinimumKey)
        if let notes, let data = try? JSONEncoder().encode(notes) {
            defaults.set(data, forKey: Self.cachedNotesKey)
        } else {
            defaults.removeObject(forKey: Self.cachedNotesKey)
        }
    }

    /// Turns the current config into a status, and decides whether the banner
    /// may appear (at most once a day, unless the published version changed).
    private func evaluate() {
        guard AppVersion.isValid(latestVersion) else {
            status = .unknown
            isBannerVisible = false
            return
        }

        let hasNewer = AppVersion.compare(installedVersion, latestVersion) == .orderedAscending
        guard hasNewer else {
            status = .upToDate
            isBannerVisible = false
            return
        }

        // A minimum above the published version would lock users out with
        // nothing to install: clamp it so blocking always has a way out.
        let effectiveMinimum = AppVersion.isValid(minimumVersion)
            && AppVersion.compare(minimumVersion, latestVersion) != .orderedDescending
            ? minimumVersion
            : latestVersion

        if AppVersion.isValid(minimumVersion),
           AppVersion.compare(installedVersion, effectiveMinimum) == .orderedAscending {
            guard status != .required else { return }
            status = .required
            isBannerVisible = false
            AnalyticsService.shared.log("update_required_shown", meta: [
                "installed": installedVersion,
                "minimum": effectiveMinimum
            ])
            return
        }

        status = .recommended
        guard !isBannerVisible else { return }
        guard shouldShowBannerToday() else { return }

        isBannerVisible = true
        defaults.set(Self.today(), forKey: Self.bannerDayKey)
        defaults.set(latestVersion, forKey: Self.bannerVersionKey)
        AnalyticsService.shared.log("update_banner_shown", meta: [
            "installed": installedVersion,
            "latest": latestVersion
        ])
    }

    /// True when the invite hasn't been shown yet today, or when a newer
    /// version than the last announced one has just been published.
    private func shouldShowBannerToday() -> Bool {
        if defaults.string(forKey: Self.bannerVersionKey) != latestVersion { return true }
        return defaults.string(forKey: Self.bannerDayKey) != Self.today()
    }

    private static func today() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

/// Numeric comparison of dotted version strings ("1.4" < "1.4.1" < "1.10").
nonisolated enum AppVersion {
    /// True when the string looks like a version ("1", "1.4", "1.4.2").
    static func isValid(_ version: String) -> Bool {
        let trimmed = version.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        return parts.allSatisfy { Int($0) != nil } && !parts.isEmpty
    }

    /// Component-wise comparison; missing trailing components count as 0.
    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = components(lhs)
        let right = components(rhs)
        for index in 0..<max(left.count, right.count) {
            let a = index < left.count ? left[index] : 0
            let b = index < right.count ? right[index] : 0
            if a < b { return .orderedAscending }
            if a > b { return .orderedDescending }
        }
        return .orderedSame
    }

    private static func components(_ version: String) -> [Int] {
        version
            .trimmingCharacters(in: .whitespaces)
            .split(separator: ".")
            .map { Int($0) ?? 0 }
    }
}
