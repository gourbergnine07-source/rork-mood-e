//
//  TVEpisodeNotifier.swift
//  MoodE
//

import Foundation
import UserNotifications

/// Schedules "new episode" notifications for the TV series the user
/// follows (Premium only, requires notifications enabled).
///
/// Air-date driven: TMDB's `next_episode_to_air` gives the DAY the
/// episode airs; the alert fires that morning at 10:00 (or right away if
/// the sync runs later on the air day). No broadcast time is ever
/// invented. Tapping the alert opens the show's detail page.
enum TVEpisodeNotifier {
    private static let identifierPrefix = "tvep-"
    private static let notifiedKey = "tv.episode.notifiedKeys"

    /// Rebuilds every episode reminder from the current follow list.
    /// Called on app open, after follow/unfollow and with the other
    /// notification schedule refreshes.
    static func sync() async {
        let center = UNUserNotificationCenter.current()

        // Rebuild from scratch so unfollows and date changes are reflected.
        let pending = await center.pendingNotificationRequests()
        let stale = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: stale)

        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "notifications.enabled"),
              PremiumStore.shared.isPremium else { return }

        let follows = TVFollowStore.shared.follows
        guard !follows.isEmpty else { return }

        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")
        let calendar = Calendar.current
        var notified = Set(defaults.stringArray(forKey: notifiedKey) ?? [])

        for show in follows {
            guard let info = try? await TMDBService.tvNextEpisode(id: show.id),
                  let rawDate = info.airDate, rawDate.count >= 10,
                  let airDate = parser.date(from: String(rawDate.prefix(10))) else { continue }

            // One alert per show per air date, never repeated.
            let dedupeKey = "\(show.id)-\(rawDate.prefix(10))"
            guard !notified.contains(dedupeKey) else { continue }
            guard calendar.isDateInToday(airDate) || airDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = L("notif.tvep.title")
            if let reference = info.episodeReference {
                content.body = LF("notif.tvep.body.ep", show.name, reference)
            } else {
                content.body = LF("notif.tvep.body", show.name)
            }
            content.sound = .default
            content.userInfo = NotificationRoute.tvShowUserInfo(
                id: show.id, name: show.name, posterPath: show.posterPath
            )

            let trigger: UNNotificationTrigger
            if let fireDate = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: airDate),
               fireDate > Date() {
                let components = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute], from: fireDate
                )
                trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            } else if calendar.isDateInToday(airDate) {
                // Synced after 10:00 on the air day: near-immediate banner.
                trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
            } else {
                continue
            }

            try? await center.add(UNNotificationRequest(
                identifier: identifierPrefix + dedupeKey,
                content: content,
                trigger: trigger
            ))
            notified.insert(dedupeKey)
        }

        defaults.set(Array(notified), forKey: notifiedKey)
    }
}
