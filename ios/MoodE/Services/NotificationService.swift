//
//  NotificationService.swift
//  MoodE
//

import Foundation
import UserNotifications
import Observation

/// Deep-link routes attached to local notifications, handled by ContentView.
enum NotificationRoute {
    static let notificationName = Notification.Name("moodE.notificationRoute")
    static let moodFlow = "moodflow"
    static let watchlist = "watchlist"
    static let community = "community"
    static let forecast = "forecast"
}

/// Manages every local notification of Mood-E:
/// - evening mood reminder (configurable time, default 20:00)
/// - watchlist reminders for movies saved 5+ days ago
/// - new releases in line with the user's recent mood/genre history
/// Each trigger can be switched on/off individually from Impostazioni.
@Observable
final class NotificationService {
    /// Master switch (persisted).
    private(set) var isEnabled: Bool
    /// Current system permission status, refreshed on scene activation.
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    /// True while a permission request or TMDB sync is running.
    private(set) var isWorking = false

    /// Per-trigger switches (persisted, default on when the master is on).
    private(set) var eveningEnabled: Bool
    private(set) var watchlistEnabled: Bool
    private(set) var releasesEnabled: Bool
    private(set) var communityEnabled: Bool
    private(set) var forecastEnabled: Bool
    private(set) var eventsEnabled: Bool
    private(set) var eventsHeadsUpEnabled: Bool

    /// Evening reminder time (persisted, default 20:00).
    private(set) var eveningHour: Int
    private(set) var eveningMinute: Int

    private static let enabledKey = "notifications.enabled"
    private static let eveningEnabledKey = "notifications.evening.enabled"
    private static let eveningHourKey = "notifications.evening.hour"
    private static let eveningMinuteKey = "notifications.evening.minute"
    private static let watchlistEnabledKey = "notifications.watchlist.enabled"
    private static let releasesEnabledKey = "notifications.releases.enabled"
    private static let communityEnabledKey = "notifications.community.enabled"
    private static let forecastEnabledKey = "notifications.forecast.enabled"
    private static let eventsEnabledKey = "notifications.events.enabled"
    private static let eventsHeadsUpEnabledKey = "notifications.events.headsUp.enabled"
    private static let communityDigestDayKey = "notifications.community.lastDigestDay"
    private static let watchlistNotifiedKey = "notifications.watchlist.notifiedIds"
    private static let featuredScheduledKey = "notifications.featured.scheduledIds"
    private static let knownIdsKey = "notifications.knownMovieIds"
    private static let lastSyncKey = "notifications.lastSyncDate"
    private static let anniversaryMonthKey = "notifications.anniversary.lastMonth"
    /// Minimum time between two TMDB checks (6 hours, like the data cache).
    private static let syncInterval: TimeInterval = 6 * 60 * 60
    /// Days a watchlist movie sits unwatched before the reminder.
    private static let watchlistReminderDays = 5

    private static let eveningIdentifier = "evening-reminder"
    private static let movieNightPrefix = "movienight-"
    private static let forecastPrefix = "forecast-"
    private static let eventPrefix = "event-"
    private static let eventHeadsUpPrefix = "eventpre-"
    /// Days before a live event for the optional heads-up notification.
    private static let eventHeadsUpDays = 3

    private let defaults = UserDefaults.standard

    init() {
        let defaults = UserDefaults.standard
        isEnabled = defaults.bool(forKey: Self.enabledKey)
        eveningEnabled = (defaults.object(forKey: Self.eveningEnabledKey) as? Bool) ?? true
        watchlistEnabled = (defaults.object(forKey: Self.watchlistEnabledKey) as? Bool) ?? true
        releasesEnabled = (defaults.object(forKey: Self.releasesEnabledKey) as? Bool) ?? true
        communityEnabled = (defaults.object(forKey: Self.communityEnabledKey) as? Bool) ?? true
        forecastEnabled = (defaults.object(forKey: Self.forecastEnabledKey) as? Bool) ?? true
        eventsEnabled = (defaults.object(forKey: Self.eventsEnabledKey) as? Bool) ?? true
        eventsHeadsUpEnabled = (defaults.object(forKey: Self.eventsHeadsUpEnabledKey) as? Bool) ?? true
        eveningHour = (defaults.object(forKey: Self.eveningHourKey) as? Int) ?? 20
        eveningMinute = (defaults.object(forKey: Self.eveningMinuteKey) as? Int) ?? 0
        Task { await refreshAuthorizationStatus() }
    }

    // MARK: - Permission & master toggle

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
            // Allow future seasonal-theme reminders to be re-armed on re-enable.
            defaults.removeObject(forKey: Self.featuredScheduledKey)
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
        return true
    }

    // MARK: - Per-trigger toggles

    func setEveningEnabled(_ enabled: Bool) {
        eveningEnabled = enabled
        defaults.set(enabled, forKey: Self.eveningEnabledKey)
        scheduleEveningReminder()
    }

    func setEveningTime(hour: Int, minute: Int) {
        eveningHour = hour
        eveningMinute = minute
        defaults.set(hour, forKey: Self.eveningHourKey)
        defaults.set(minute, forKey: Self.eveningMinuteKey)
        scheduleEveningReminder()
    }

    func setWatchlistEnabled(_ enabled: Bool, toWatch: [LibraryEntry]) {
        watchlistEnabled = enabled
        defaults.set(enabled, forKey: Self.watchlistEnabledKey)
        if enabled {
            scheduleWatchlistReminder(toWatch: toWatch)
        } else {
            cancelWatchlistReminders()
        }
    }

    func setCommunityEnabled(_ enabled: Bool) {
        communityEnabled = enabled
        defaults.set(enabled, forKey: Self.communityEnabledKey)
    }

    /// Toggles the proactive weekday mood-forecast notification.
    func setForecastEnabled(_ enabled: Bool, checkIns: [MoodCheckIn]) {
        forecastEnabled = enabled
        defaults.set(enabled, forKey: Self.forecastEnabledKey)
        Task {
            if enabled {
                await syncMoodForecast(checkIns: checkIns)
            } else {
                await removePending(prefix: Self.forecastPrefix)
            }
        }
    }

    /// Toggles the live cinema event notifications (day-of).
    func setEventsEnabled(_ enabled: Bool) {
        eventsEnabled = enabled
        defaults.set(enabled, forKey: Self.eventsEnabledKey)
        Task {
            if enabled {
                await syncLiveEventReminders()
            } else {
                await removePending(prefix: Self.eventPrefix)
                await removePending(prefix: Self.eventHeadsUpPrefix)
            }
        }
    }

    /// Toggles the optional 3-days-before heads-up for live events.
    func setEventsHeadsUpEnabled(_ enabled: Bool) {
        eventsHeadsUpEnabled = enabled
        defaults.set(enabled, forKey: Self.eventsHeadsUpEnabledKey)
        Task {
            if enabled {
                await syncLiveEventReminders()
            } else {
                await removePending(prefix: Self.eventHeadsUpPrefix)
            }
        }
    }

    private func removePending(prefix: String) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    func setReleasesEnabled(_ enabled: Bool) {
        releasesEnabled = enabled
        defaults.set(enabled, forKey: Self.releasesEnabledKey)
        if !enabled {
            Task {
                let center = UNUserNotificationCenter.current()
                let pending = await center.pendingNotificationRequests()
                let releaseIds = pending.map(\.identifier).filter { $0.hasPrefix("release-") }
                center.removePendingNotificationRequests(withIdentifiers: releaseIds)
            }
        }
    }

    /// Re-applies every schedule; called on scene activation and after the
    /// master toggle turns on.
    func refreshSchedules(
        toWatch: [LibraryEntry],
        topGenres: [Int],
        scheduled: [ScheduledMovie] = [],
        checkIns: [MoodCheckIn] = []
    ) async {
        guard isEnabled else { return }
        scheduleEveningReminder()
        scheduleWatchlistReminder(toWatch: toWatch)
        syncMovieNightReminders(scheduled)
        await syncFeaturedThemeReminders()
        await syncAnniversaryReminder(checkIns: checkIns)
        await syncMoodForecast(checkIns: checkIns)
        await syncLiveEventReminders()
        await sync(topGenres: topGenres)
    }

    // MARK: - "Un anno fa oggi" anniversary

    /// Schedules at most ONE memory notification per calendar month:
    /// the next day (within 4 weeks) that has a check-in exactly one year
    /// earlier. Skipped entirely when no anniversary falls in the window.
    func syncAnniversaryReminder(checkIns: [MoodCheckIn]) async {
        guard isEnabled, !checkIns.isEmpty else { return }

        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        for offset in 0..<28 {
            guard let candidate = calendar.date(byAdding: .day, value: offset, to: Date()),
                  let yearAgo = calendar.date(byAdding: .year, value: -1, to: candidate),
                  let fireDate = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: candidate),
                  fireDate > Date() else { continue }

            guard let hit = checkIns.first(where: { calendar.isDate($0.date, inSameDayAs: yearAgo) }),
                  let mood = hit.mood else { continue }

            // Max one per month: remembered by the month of the fire date.
            let monthKey = formatter.string(from: fireDate)
            guard defaults.string(forKey: Self.anniversaryMonthKey) != monthKey else { return }

            let content = UNMutableNotificationContent()
            content.title = L("notif.anniversary.title")
            content.body = LF("notif.anniversary.body", mood.title.lowercased())
            content.sound = .default
            content.userInfo = ["route": NotificationRoute.moodFlow]

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            try? await UNUserNotificationCenter.current().add(UNNotificationRequest(
                identifier: "anniversary-\(monthKey)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            ))
            defaults.set(monthKey, forKey: Self.anniversaryMonthKey)
            return
        }
    }

    // MARK: - Mood forecast

    /// Weekly proactive notification for each detected weekday-mood pattern
    /// ("Di solito il lunedì ti senti stressato…"), fired at the user's
    /// typical check-in hour. Rebuilt from scratch so patterns stay current.
    func syncMoodForecast(checkIns: [MoodCheckIn]) async {
        await removePending(prefix: Self.forecastPrefix)
        guard isEnabled, forecastEnabled else { return }

        let patterns = MoodForecastAnalyzer.patterns(from: checkIns)
        guard !patterns.isEmpty else { return }

        let center = UNUserNotificationCenter.current()
        for pattern in patterns {
            guard let mood = Mood(rawValue: pattern.moodRaw) else { continue }

            let content = UNMutableNotificationContent()
            content.title = L("notif.forecast.title")
            content.body = LF(
                "notif.forecast.body",
                MoodForecastAnalyzer.weekdayName(pattern.weekday),
                mood.title.lowercased()
            )
            content.sound = .default
            content.userInfo = [
                "route": NotificationRoute.forecast,
                "mood": pattern.moodRaw,
                "goal": pattern.goalRaw
            ]

            var components = DateComponents()
            components.weekday = pattern.weekday
            components.hour = pattern.hour
            components.minute = pattern.minute

            try? await center.add(UNNotificationRequest(
                identifier: Self.forecastPrefix + "\(pattern.weekday)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            ))
        }
    }

    // MARK: - Live cinema events

    /// Day-of notification (18:00) for each upcoming live event, plus an
    /// optional heads-up 3 days before (10:00) when enabled.
    func syncLiveEventReminders() async {
        guard isEnabled, eventsEnabled else { return }

        let center = UNUserNotificationCenter.current()
        let pendingIds = Set(await center.pendingNotificationRequests().map(\.identifier))
        let calendar = Calendar.current

        for event in LiveEventCalendar.all {
            guard let eventDay = event.nextDate(onOrAfter: Date()) else { continue }
            let year = calendar.component(.year, from: eventDay)

            let dayOfId = Self.eventPrefix + "\(event.id)-\(year)"
            if !pendingIds.contains(dayOfId),
               let fireDate = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: eventDay),
               fireDate > Date() {
                let content = UNMutableNotificationContent()
                content.title = L("notif.event.title")
                content.body = L("notif.event.\(event.id)")
                content.sound = .default
                content.userInfo = ["route": NotificationRoute.moodFlow]

                let components = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute], from: fireDate
                )
                try? await center.add(UNNotificationRequest(
                    identifier: dayOfId,
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                ))
            }

            guard eventsHeadsUpEnabled else { continue }
            let headsUpId = Self.eventHeadsUpPrefix + "\(event.id)-\(year)"
            if !pendingIds.contains(headsUpId),
               let headsUpDay = calendar.date(byAdding: .day, value: -Self.eventHeadsUpDays, to: eventDay),
               let fireDate = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: headsUpDay),
               fireDate > Date() {
                let content = UNMutableNotificationContent()
                content.title = L("notif.event.title")
                content.body = LF("notif.event.pre.body", event.title, Self.eventHeadsUpDays)
                content.sound = .default
                content.userInfo = ["route": NotificationRoute.moodFlow]

                let components = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute], from: fireDate
                )
                try? await center.add(UNNotificationRequest(
                    identifier: headsUpId,
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                ))
            }
        }
    }

    // MARK: - Seasonal collection reminders

    /// One-shot local notification on the first day of each seasonal
    /// collection ("\u{1F383} È iniziato ottobre…"). At most one per theme per
    /// year: fired ids are remembered so the same season never repeats.
    private func syncFeaturedThemeReminders() async {
        guard isEnabled else { return }

        let center = UNUserNotificationCenter.current()
        var scheduledIds = Set(defaults.array(forKey: Self.featuredScheduledKey) as? [String] ?? [])
        let calendar = Calendar.current

        for collection in FeaturedCalendar.seasonal {
            guard let start = collection.period?.nextStart(after: Date()) else { continue }
            let year = calendar.component(.year, from: start)
            let identifier = "featured-\(collection.id)-\(year)"
            guard !scheduledIds.contains(identifier) else { continue }

            let content = UNMutableNotificationContent()
            content.title = L("notif.featured.title")
            content.body = L("notif.featured.\(collection.id)")
            content.sound = .default
            content.userInfo = ["route": NotificationRoute.moodFlow]

            var components = calendar.dateComponents([.year, .month, .day], from: start)
            components.hour = 10

            try? await center.add(UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            ))
            scheduledIds.insert(identifier)
        }

        defaults.set(Array(scheduledIds), forKey: Self.featuredScheduledKey)
    }

    // MARK: - Community (Consigli) notifications

    /// Immediate banner when someone replied to the user's advice request.
    func notifyCommunityReplies(_ count: Int) {
        guard isEnabled, communityEnabled, count > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = L("notif.community.reply.title")
        content.body = count == 1
            ? L("notif.community.reply.body")
            : LF("notif.community.reply.many", count)
        content.sound = .default
        content.userInfo = ["route": NotificationRoute.community]

        let request = UNNotificationRequest(
            identifier: "community-reply-\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Daily digest (at most once per day) about new requests published by
    /// people feeling the user's most frequent mood.
    func notifyCommunityMoodMatches(count: Int, mood: Mood) {
        guard isEnabled, communityEnabled, count > 0 else { return }

        let today = Self.dayKey(for: Date())
        guard defaults.string(forKey: Self.communityDigestDayKey) != today else { return }
        defaults.set(today, forKey: Self.communityDigestDayKey)

        let content = UNMutableNotificationContent()
        content.title = L("notif.community.mood.title")
        content.body = count == 1
            ? LF("notif.community.mood.one", mood.title)
            : LF("notif.community.mood.body", count, mood.title)
        content.sound = .default
        content.userInfo = ["route": NotificationRoute.community]

        let request = UNNotificationRequest(
            identifier: "community-digest-\(today)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    private static func dayKey(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    // MARK: - Movie night reminders

    /// One reminder per planned movie, on its day at the user's evening
    /// time ("Stasera hai in programma … 🍿"). Rebuilt from scratch on every
    /// call so moves and removals are always reflected.
    func syncMovieNightReminders(_ scheduled: [ScheduledMovie]) {
        Task {
            let center = UNUserNotificationCenter.current()
            let pending = await center.pendingNotificationRequests()
            let staleIds = pending.map(\.identifier).filter { $0.hasPrefix(Self.movieNightPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: staleIds)

            guard isEnabled else { return }

            let calendar = Calendar.current
            for movie in scheduled {
                guard let fireDate = calendar.date(
                    bySettingHour: eveningHour, minute: eveningMinute, second: 0, of: movie.day
                ), fireDate > Date() else { continue }

                let content = UNMutableNotificationContent()
                content.title = L("notif.movienight.title")
                content.body = LF("notif.movienight.body", movie.title)
                content.sound = .default
                content.userInfo = ["route": NotificationRoute.watchlist]

                let components = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute], from: fireDate
                )
                try? await center.add(UNNotificationRequest(
                    identifier: Self.movieNightPrefix + movie.id.uuidString,
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                ))
            }
        }
    }

    // MARK: - Evening mood reminder

    /// Daily repeating reminder at the user's chosen time. Tapping it opens
    /// the app straight on step 1 of the mood flow.
    private func scheduleEveningReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.eveningIdentifier])
        guard isEnabled, eveningEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = L("notif.evening.title")
        content.body = L("notif.evening.body")
        content.sound = .default
        content.userInfo = ["route": NotificationRoute.moodFlow]

        var components = DateComponents()
        components.hour = eveningHour
        components.minute = eveningMinute

        let request = UNNotificationRequest(
            identifier: Self.eveningIdentifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )
        center.add(request)
    }

    // MARK: - Watchlist reminders

    /// Gentle reminder for the oldest movie saved 5+ days ago and never
    /// notified before. Fires at 18:30 (today if still ahead, else tomorrow).
    private func scheduleWatchlistReminder(toWatch: [LibraryEntry]) {
        guard isEnabled, watchlistEnabled else { return }

        let notified = Set(defaults.array(forKey: Self.watchlistNotifiedKey) as? [Int] ?? [])
        let cutoff = Date().addingTimeInterval(-Double(Self.watchlistReminderDays) * 24 * 60 * 60)

        guard let candidate = toWatch
            .filter({ $0.addedDate <= cutoff && !notified.contains($0.id) })
            .min(by: { $0.addedDate < $1.addedDate }) else { return }

        let calendar = Calendar.current
        var fireDate = calendar.date(
            bySettingHour: 18, minute: 30, second: 0, of: Date()
        ) ?? Date().addingTimeInterval(3600)
        if fireDate.timeIntervalSinceNow < 60 * 30 {
            fireDate = calendar.date(byAdding: .day, value: 1, to: fireDate) ?? fireDate
        }
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)

        let content = UNMutableNotificationContent()
        content.title = L("notif.watchlist.title")
        content.body = LF("notif.watchlist.body", candidate.title)
        content.sound = .default
        content.userInfo = ["route": NotificationRoute.watchlist]

        let request = UNNotificationRequest(
            identifier: "watchlist-\(candidate.id)",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)

        defaults.set(Array(notified.union([candidate.id])), forKey: Self.watchlistNotifiedKey)
    }

    private func cancelWatchlistReminders() {
        Task {
            let center = UNUserNotificationCenter.current()
            let pending = await center.pendingNotificationRequests()
            let ids = pending.map(\.identifier).filter { $0.hasPrefix("watchlist-") }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    // MARK: - New releases (TMDB sync)

    /// Checks TMDB for new arrivals and upcoming cinema releases.
    /// When the user has a mood history, releases are prioritized by their
    /// most recurring genres of the last month.
    func sync(force: Bool = false, topGenres: [Int] = []) async {
        guard isEnabled, releasesEnabled else { return }

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
            var newMovies = allMovies.filter { !known.contains($0.id) }

            // With enough history, favor movies matching the user's top genres.
            if !topGenres.isEmpty {
                let preferred = newMovies.filter { movie in
                    guard let genres = movie.genreIds else { return false }
                    return !Set(genres).isDisjoint(with: topGenres)
                }
                if !preferred.isEmpty { newMovies = preferred }
            }

            defaults.set(Array(known.union(allMovies.map(\.id))), forKey: Self.knownIdsKey)

            // First sync only seeds the known set: no notification burst.
            if !isFirstSync && !newMovies.isEmpty {
                notifyNewArrivals(Array(newMovies.prefix(3)), totalCount: newMovies.count)
            }

            await scheduleReleaseReminders(for: upcoming, topGenres: topGenres)
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
    /// With history available, only releases matching the user's top genres.
    private func scheduleReleaseReminders(for movies: [TMDBMovie], topGenres: [Int]) async {
        let center = UNUserNotificationCenter.current()
        let pendingIds = Set(await center.pendingNotificationRequests().map(\.identifier))

        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")

        var candidates = Array(movies.prefix(30))
        if !topGenres.isEmpty {
            let preferred = candidates.filter { movie in
                guard let genres = movie.genreIds else { return false }
                return !Set(genres).isDisjoint(with: topGenres)
            }
            if !preferred.isEmpty { candidates = preferred }
        }

        for movie in candidates {
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

/// Shows notification banners in the foreground and routes notification taps
/// (evening reminder → mood flow, watchlist reminder → La mia lista).
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let record = NotificationHistory.payload(from: notification)
        await MainActor.run {
            NotificationHistory.shared.add(record)
        }
        return [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let record = NotificationHistory.payload(from: response.notification, isRead: true)
        let userInfo = response.notification.request.content.userInfo
        let route = userInfo["route"] as? String
        let extras = userInfo as? [String: Any]
        await MainActor.run {
            NotificationHistory.shared.add(record)
            AnalyticsService.shared.log("notification_opened", meta: ["route": route ?? "none"])
            if let route {
                NotificationCenter.default.post(
                    name: NotificationRoute.notificationName,
                    object: route,
                    userInfo: extras
                )
            }
        }
    }
}
