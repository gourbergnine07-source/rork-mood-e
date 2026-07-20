//
//  AnalyticsService.swift
//  MoodE
//

import Foundation
import Network

/// One queued usage event, persisted locally until it reaches the server.
nonisolated private struct PendingAnalyticsEvent: Codable {
    let event: String
    let meta: [String: String]
    let createdAt: Date
}

/// Row shape of the `app_events` table (snake_case columns).
nonisolated private struct AnalyticsEventRow: Encodable {
    let event: String
    let anonId: String
    let meta: [String: String]
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case event, meta
        case anonId = "anon_id"
        case createdAt = "created_at"
    }
}

/// Anonymous, aggregate-only usage analytics.
///
/// Privacy by design:
/// - the only identifier is a random UUID generated locally at first launch,
///   different for every install and never linked to the person;
/// - no names, emails, nicknames, message text, IDFA or precise location
///   ever pass through this pipeline — just an event name, a timestamp and
///   a tiny non-personal meta dictionary;
/// - requests are sent with the public anonymous key only (never the user's
///   session token), so events can't be joined with any account data.
///
/// Events queue locally (UserDefaults) and are flushed in batches only when
/// the connection is good (reachable and not in Low Data Mode), so offline
/// usage is counted once connectivity returns. Failures are silent:
/// analytics must never affect the user experience.
final class AnalyticsService {
    static let shared = AnalyticsService()

    private static let anonIdKey = "analytics.anonId"
    private static let queueKey = "analytics.queue"
    /// Oldest events are dropped beyond this size (analytics is best-effort).
    private static let maxQueue = 300

    /// Random per-install identifier, not tied to the person or device.
    private let anonId: String
    private var queue: [PendingAnalyticsEvent]
    private var isFlushing = false

    /// True when the network path is satisfied and not constrained
    /// (Low Data Mode): the only state in which batches are sent.
    private var hasGoodConnection = false
    private let pathMonitor = NWPathMonitor()

    private let defaults = UserDefaults.standard

    private init() {
        let defaults = UserDefaults.standard
        if let stored = defaults.string(forKey: Self.anonIdKey) {
            anonId = stored
        } else {
            let fresh = UUID().uuidString
            defaults.set(fresh, forKey: Self.anonIdKey)
            anonId = fresh
        }
        if let data = defaults.data(forKey: Self.queueKey),
           let stored = try? JSONDecoder().decode([PendingAnalyticsEvent].self, from: data) {
            queue = stored
        } else {
            queue = []
        }
        startNetworkMonitor()
    }

    /// Watches connectivity; when a good connection appears, the queued
    /// events are flushed automatically.
    private func startNetworkMonitor() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            let good = path.status == .satisfied && !path.isConstrained
            Task { @MainActor in
                guard let self else { return }
                let becameGood = good && !self.hasGoodConnection
                self.hasGoodConnection = good
                if becameGood {
                    await self.flush()
                }
            }
        }
        pathMonitor.start(queue: DispatchQueue(label: "analytics.network.monitor"))
    }

    // MARK: - Public API

    /// Queues an anonymous event and tries to flush right away.
    /// `meta` must contain only non-personal values (feature ids, routes…).
    func log(_ event: String, meta: [String: String] = [:]) {
        queue.append(PendingAnalyticsEvent(event: event, meta: meta, createdAt: Date()))
        if queue.count > Self.maxQueue {
            queue.removeFirst(queue.count - Self.maxQueue)
        }
        persistQueue()
        if hasGoodConnection {
            Task { await flush() }
        }
    }

    /// Sends every queued event in one batch insert, but only over a good
    /// connection. Safe to call anytime: with no network the events simply
    /// stay in the persisted queue.
    func flush() async {
        guard hasGoodConnection else { return }
        guard !isFlushing, !queue.isEmpty else { return }
        guard let url = URL(string: Config.EXPO_PUBLIC_SUPABASE_URL + "/rest/v1/app_events"),
              url.host?.contains("supabase") == true else { return }

        isFlushing = true
        defer { isFlushing = false }

        let batch = queue
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let rows = batch.map {
            AnalyticsEventRow(
                event: $0.event,
                anonId: anonId,
                meta: $0.meta,
                createdAt: formatter.string(from: $0.createdAt)
            )
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Anonymous key only: analytics requests never carry the user session.
        request.setValue(Config.EXPO_PUBLIC_SUPABASE_ANON_KEY, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(Config.EXPO_PUBLIC_SUPABASE_ANON_KEY)", forHTTPHeaderField: "Authorization")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")

        do {
            request.httpBody = try JSONEncoder().encode(rows)
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else { return }
            // New events may have been appended while awaiting: drop only the sent prefix.
            queue.removeFirst(min(batch.count, queue.count))
            persistQueue()
        } catch {
            // Keep the queue; a later flush will retry.
        }
    }

    private func persistQueue() {
        guard let data = try? JSONEncoder().encode(queue) else { return }
        defaults.set(data, forKey: Self.queueKey)
    }
}
