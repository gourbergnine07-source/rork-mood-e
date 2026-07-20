//
//  CommunityService.swift
//  MoodE
//

import Foundation
import Observation

/// Errors surfaced by the community networking layer.
nonisolated enum CommunityError: LocalizedError {
    case offensive
    case rateLimited
    case network

    var errorDescription: String? {
        switch self {
        case .offensive: return LN("advice.moderation.blocked")
        case .rateLimited: return LN("advice.rateLimited")
        case .network: return LN("advice.error")
        }
    }
}

/// Anonymous community client for the "Consigli" board.
/// Users are identified only by a random device id (never leaves the app
/// except as an opaque token) and a self-generated anonymous nickname.
/// No account, no personal data, no private messaging.
@Observable
final class CommunityService {
    static let shared = CommunityService()

    /// Opaque random identifier for this install (not tied to the person).
    private(set) var deviceId: String
    /// Anonymous public nickname shown next to requests and replies.
    private(set) var nickname: String
    /// Personal counters (helpful marks received, requests published…).
    private(set) var profile: CommunityProfile
    /// Content hidden locally by the user ("Nascondi").
    private(set) var hiddenIds: Set<String>
    /// Whether the one-time privacy notice has been dismissed.
    private(set) var hasSeenPrivacyNotice: Bool

    private static let deviceIdKey = "community.deviceId"
    private static let nicknameKey = "community.nickname"
    private static let hiddenKey = "community.hiddenIds"
    private static let noticeKey = "community.noticeSeen"
    private static let lastCheckKey = "community.lastActivityCheck"
    static let helpfulReceivedKey = "community.helpfulReceived"
    static let requestsPublishedKey = "community.requestsPublished"

    private let defaults = UserDefaults.standard

    private init() {
        let defaults = UserDefaults.standard
        if let stored = defaults.string(forKey: Self.deviceIdKey) {
            deviceId = stored
        } else {
            let fresh = UUID().uuidString
            defaults.set(fresh, forKey: Self.deviceIdKey)
            deviceId = fresh
        }
        if let stored = defaults.string(forKey: Self.nicknameKey) {
            nickname = stored
        } else {
            let fresh = Self.generateNickname()
            defaults.set(fresh, forKey: Self.nicknameKey)
            nickname = fresh
        }
        hiddenIds = Set(defaults.stringArray(forKey: Self.hiddenKey) ?? [])
        hasSeenPrivacyNotice = defaults.bool(forKey: Self.noticeKey)
        profile = CommunityProfile(
            helpfulReceived: defaults.integer(forKey: Self.helpfulReceivedKey),
            requestsPublished: defaults.integer(forKey: Self.requestsPublishedKey),
            repliesGiven: 0
        )
    }

    // MARK: - Nickname

    private static let nicknamePrefixes = [
        "Retro", "Nova", "Luna", "Ciak", "Pop", "Indie", "Neo", "Vega",
        "Astro", "Melo", "Nitro", "Echo"
    ]
    private static let nicknameSuffixes = [
        "Reel", "Star", "Scene", "Frame", "Kino", "Wave", "Lume", "Club",
        "Movie", "Flick"
    ]

    private static func generateNickname() -> String {
        let prefix = nicknamePrefixes.randomElement() ?? "Ciak"
        let suffix = nicknameSuffixes.randomElement() ?? "Reel"
        return "\(prefix)\(suffix)\(Int.random(in: 10...99))"
    }

    /// Replaces the anonymous nickname with a freshly generated one.
    func regenerateNickname() {
        nickname = Self.generateNickname()
        defaults.set(nickname, forKey: Self.nicknameKey)
    }

    // MARK: - Privacy notice & local hiding

    func dismissPrivacyNotice() {
        hasSeenPrivacyNotice = true
        defaults.set(true, forKey: Self.noticeKey)
    }

    /// Hides a request or reply locally (personal choice, no server call).
    func hide(id: String) {
        hiddenIds.insert(id)
        defaults.set(Array(hiddenIds), forKey: Self.hiddenKey)
    }

    // MARK: - API

    /// Newest public requests, optionally filtered by mood.
    func loadRequests(mood: Mood?) async throws -> [AdviceRequest] {
        var query = "deviceId=\(deviceId)"
        if let mood { query += "&mood=\(mood.rawValue)" }
        let payload: RequestsPayload = try await get("/advice/requests?\(query)")
        return payload.requests.filter { !hiddenIds.contains($0.id) }
    }

    /// Publishes a new anonymous advice request.
    func publishRequest(mood: Mood, text: String) async throws -> AdviceRequest {
        guard ContentModeration.isClean(text) else { throw CommunityError.offensive }
        let payload: RequestPayload = try await post("/advice/requests", body: [
            "deviceId": deviceId,
            "nickname": nickname,
            "mood": mood.rawValue,
            "text": text
        ])
        await refreshProfile()
        return payload.request
    }

    /// Full request detail with its replies (most helpful first).
    func loadDetail(id: String) async throws -> AdviceDetail {
        let detail: AdviceDetail = try await get("/advice/requests/\(id)?deviceId=\(deviceId)")
        return AdviceDetail(
            request: detail.request,
            replies: detail.replies.filter { !hiddenIds.contains($0.id) }
        )
    }

    /// Replies to a request suggesting a specific TMDB movie.
    func sendReply(requestId: String, movie: TMDBMovie, text: String) async throws -> AdviceReply {
        guard ContentModeration.isClean(text) else { throw CommunityError.offensive }
        var body: [String: Any] = [
            "deviceId": deviceId,
            "nickname": nickname,
            "requestId": requestId,
            "movieId": movie.id,
            "movieTitle": movie.title,
            "text": text
        ]
        if let poster = movie.posterPath { body["posterPath"] = poster }
        let payload: ReplyPayload = try await post("/advice/replies", body: body)
        await refreshProfile()
        return payload.reply
    }

    /// Marks a received reply as helpful (once per reply, requester only).
    func markHelpful(replyId: String) async throws {
        let _: HelpfulPayload = try await post("/advice/helpful", body: [
            "deviceId": deviceId,
            "replyId": replyId
        ])
    }

    /// Reports a request or reply for moderation (hidden after 3 reports).
    func report(targetType: String, targetId: String) async {
        let _: OkPayload? = try? await post("/advice/report", body: [
            "deviceId": deviceId,
            "targetType": targetType,
            "targetId": targetId
        ])
    }

    /// Anonymous aggregate stats for the "moods of the week" card.
    func loadStats() async throws -> AdviceStats {
        try await get("/advice/stats")
    }

    /// Refreshes the personal counters and persists them for badge checks.
    func refreshProfile() async {
        guard let fresh: CommunityProfile = try? await get("/advice/profile?deviceId=\(deviceId)") else { return }
        profile = fresh
        defaults.set(fresh.helpfulReceived, forKey: Self.helpfulReceivedKey)
        defaults.set(fresh.requestsPublished, forKey: Self.requestsPublishedKey)
    }

    // MARK: - Return notifications (checked on app activation)

    /// Polls the board for new replies to the user's requests and for new
    /// requests matching their most frequent mood, then hands the results
    /// to the local notification system (Prompt 14 pipeline).
    func checkActivity(notifications: NotificationService, topMood: Mood?) async {
        await refreshProfile()
        guard notifications.isEnabled, notifications.communityEnabled else { return }

        let since = defaults.double(forKey: Self.lastCheckKey)
        var query = "deviceId=\(deviceId)&since=\(Int(since))"
        if let topMood { query += "&mood=\(topMood.rawValue)" }

        guard let activity: ActivityPayload = try? await get("/advice/activity?\(query)") else { return }
        defaults.set(activity.now, forKey: Self.lastCheckKey)

        if since > 0, activity.newReplies > 0 {
            notifications.notifyCommunityReplies(activity.newReplies)
        }
        if let topMood, activity.moodMatches > 0 {
            notifications.notifyCommunityMoodMatches(count: activity.moodMatches, mood: topMood)
        }
    }

    // MARK: - Networking

    private var baseURL: URL? {
        URL(string: Config.EXPO_PUBLIC_RORK_FUNCTIONS_URL)
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        guard let base = baseURL, let url = URL(string: base.absoluteString + path) else {
            throw CommunityError.network
        }
        return try await perform(URLRequest(url: url))
    }

    private func post<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        guard let base = baseURL, let url = URL(string: base.absoluteString + path) else {
            throw CommunityError.network
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await perform(request)
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw CommunityError.network
        }
        guard let http = response as? HTTPURLResponse else { throw CommunityError.network }
        guard (200...299).contains(http.statusCode) else {
            if let error = try? JSONDecoder().decode(ErrorPayload.self, from: data) {
                if error.code == "offensive" { throw CommunityError.offensive }
                if error.code == "rate_limited" { throw CommunityError.rateLimited }
            }
            throw CommunityError.network
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("[Community] Decoding error: \(error)")
            throw CommunityError.network
        }
    }
}

// MARK: - Payload wrappers

private nonisolated struct RequestsPayload: Decodable { let requests: [AdviceRequest] }
private nonisolated struct RequestPayload: Decodable { let request: AdviceRequest }
private nonisolated struct ReplyPayload: Decodable { let reply: AdviceReply }
private nonisolated struct HelpfulPayload: Decodable { let ok: Bool; let helpfulCount: Int }
private nonisolated struct OkPayload: Decodable { let ok: Bool }
private nonisolated struct ActivityPayload: Decodable { let newReplies: Int; let moodMatches: Int; let now: Double }
private nonisolated struct ErrorPayload: Decodable { let error: String; let code: String? }
