//
//  NotificationService.swift
//  MoodE
//

import Foundation
import UserNotifications
import Observation

/// Manages local notifications for new TMDB arrivals and cinema release days.
/// The user switches notifications on/off from the Impostazioni tab.
@Observable
final class NotificationService {
    /// Whether the user has notifications switched on (persisted).
    private(set) var isEnabled: Bool
    /// Current system permission status, refreshed on scene activation.
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    /// True while a permission request or TMDB sync is running.
    private(set) var isWorking = false

    private static let enabledKey = "notifications.enabled"
    private static let knownIdsKey = "notifications.knownMovieIds"
    private static let lastSyncKey = "notifications.lastSyncDate"
    /// Minimum time between two TMDB checks (6 hours, like the data cache).
    private static let syncInterval: TimeInterval = 6 * 60 * 60

    private let defaults = UserDefaults.standard

    init() {
        isEnabled = defaults.bool(forKey: Self.enabledKey)
        Task { await refreshAuthorizationStatus() }
    }

    // MARK: - Permission & toggle

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    /// Turns notifications on (asking system permission if needed) or off.
    /// Returns false when the system permission is denied.
    @discardableResult
    func setEnabled(_ enabled: Bool) async -> Bool {
        if !enabled {
            isEnabled = false
            defaults.set(false, forKey: Self.enabledKey)
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            return true
        }

        isWorking = true
        defer { isWorking = false }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            await refreshAuthorizationStatus()
            guard granted else { return false }
        case .denied:
            await refreshAuthorizationStatus()
            return false
        default:
            break
        }

        isEnabled = true
        defaults.set(true, forKey: Self.enabledKey)
        await sync(force: true)
        return true
    }

    // MARK: - Sync with TMDB

    /// Checks TMDB for new arrivals and upcoming cinema releases.
    /// Fires an immediate notification for genuinely new movies and
    /// schedules release-day reminders for upcoming films.
    func sync(force: Bool = false) async {
        guard isEnabled else { return }

        if !force,
           let last = defaults.object(forKey: Self.lastSyncKey) as? Date,
           Date().timeIntervalSince(last) < Self.syncInterval {
            return
        }

        let region = Locale.current.region?.identifier ?? "IT"

        do {
            async let nowPlayingTask = TMDBService.nowPlayingMovies(region: region)
            async let upcomingTask = TMDBService.upcomingMovies(region: region)
            let (nowPlaying, upcoming) = try await (nowPlayingTask, upcomingTask)

            defaults.set(Date(), forKey: Self.lastSyncKey)

            let known = Set(defaults.array(forKey: Self.knownIdsKey) as? [Int] ?? [])
            let isFirstSync = known.isEmpty

            var seenInBatch = Set<Int>()
            let allMovies = (nowPlaying + upcoming).filter { seenInBatch.insert($0.id).inserted }
            let newMovies = allMovies.filter { !known.contains($0.id) }

            defaults.set(Array(known.union(allMovies.map(\.id))), forKey: Self.knownIdsKey)

            // First sync only seeds the known set: no notification burst.
            if !isFirstSync && !newMovies.isEmpty {
                notifyNewArrivals(Array(newMovies.prefix(3)), totalCount: newMovies.count)
            }

            await scheduleReleaseReminders(for: upcoming)
        } catch {
            print("[Notifications] Sync failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Notification builders

    /// Immediate banner for movies that just appeared on TMDB.
    private func notifyNewArrivals(_ movies: [TMDBMovie], totalCount: Int) {
        guard let first = movies.first else { return }

        let content = UNMutableNotificationContent()
        content.title = L("notif.new.title")
        if totalCount == 1 {
            content.body = LF("notif.new.one", first.title)
        } else {
            let titles = movies.map(\.title).joined(separator: ", ")
            let extra = totalCount - movies.count
            content.body = extra > 0
                ? LF("notif.new.manyExtra", titles, extra)
                : LF("notif.new.many", titles)
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "new-arrivals-\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Schedules a local reminder at 10:00 on each upcoming movie's release day.
    private func scheduleReleaseReminders(for movies: [TMDBMovie]) async {
        let center = UNUserNotificationCenter.current()
        let pendingIds = Set(await center.pendingNotificationRequests().map(\.identifier))

        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")

        for movie in movies.prefix(30) {
            let identifier = "release-\(movie.id)"
            guard !pendingIds.contains(identifier),
                  let dateString = movie.releaseDate,
                  let releaseDate = parser.date(from: dateString),
                  releaseDate > Date() else { continue }

            var components = Calendar.current.dateComponents([.year, .month, .day], from: releaseDate)
            components.hour = 10

            let content = UNMutableNotificationContent()
            content.title = L("notif.release.title")
            content.body = LF("notif.release.body", movie.title)
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
            try? await center.add(request)
        }
    }
}

/// Shows notification banners even while the app is in the foreground.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
