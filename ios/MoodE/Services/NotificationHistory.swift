//
//  NotificationHistory.swift
//  MoodE
//

import Foundation
import UserNotifications
import Observation

/// A saved copy of a notification shown to the user, kept so it can be
/// re-read anytime from the in-app notification center.
nonisolated struct NotificationRecord: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let body: String
    let date: Date
    let route: String?
    var isRead: Bool
}

/// Persists every notification Mood-E delivers (evening reminder, watchlist
/// nudges, new releases) so the user can browse them later from the bell
/// icon in the Home tab. Stored locally in UserDefaults, newest first.
@Observable
final class NotificationHistory {
    static let shared = NotificationHistory()

    private(set) var records: [NotificationRecord] = []

    var unreadCount: Int { records.filter { !$0.isRead }.count }

    private static let storageKey = "notifications.history"
    private static let maxRecords = 50
    private let defaults = UserDefaults.standard

    private init() {
        if let data = defaults.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode([NotificationRecord].self, from: data) {
            records = saved
        }
    }

    // MARK: - Recording

    /// Adds a record if not already saved (dedupe by id).
    func add(_ record: NotificationRecord) {
        guard !records.contains(where: { $0.id == record.id }) else { return }
        records.append(record)
        records.sort { $0.date > $1.date }
        if records.count > Self.maxRecords {
            records = Array(records.prefix(Self.maxRecords))
        }
        persist()
    }

    /// Imports every notification still sitting in the system Notification
    /// Center — catches the ones delivered while the app was closed.
    func syncDelivered() async {
        let payloads = await Self.deliveredPayloads()
        for payload in payloads { add(payload) }
    }

    // MARK: - Reading & cleanup

    func markAllRead() {
        guard records.contains(where: { !$0.isRead }) else { return }
        for index in records.indices { records[index].isRead = true }
        persist()
    }

    func delete(_ record: NotificationRecord) {
        records.removeAll { $0.id == record.id }
        persist()
    }

    func clear() {
        records.removeAll()
        persist()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }

    // MARK: - Payload extraction (background-safe)

    /// Builds a Sendable record from a UNNotification; safe to call from the
    /// notification delegate's nonisolated context.
    nonisolated static func payload(from notification: UNNotification, isRead: Bool = false) -> NotificationRecord {
        let content = notification.request.content
        let day = Int(notification.date.timeIntervalSince1970 / 86_400)
        return NotificationRecord(
            id: "\(notification.request.identifier)#\(day)",
            title: content.title,
            body: content.body,
            date: notification.date,
            route: content.userInfo["route"] as? String,
            isRead: isRead
        )
    }

    nonisolated static func deliveredPayloads() async -> [NotificationRecord] {
        let delivered = await UNUserNotificationCenter.current().deliveredNotifications()
        return delivered.map { payload(from: $0) }
    }
}
