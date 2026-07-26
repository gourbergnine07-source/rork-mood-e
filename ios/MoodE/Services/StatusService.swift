//
//  StatusService.swift
//  MoodE
//

import Foundation
import Observation

/// Client for the ephemeral "Stato Mood" board.
/// Fully anonymous like the advice community: reuses the same opaque
/// device id and self-generated nickname, no account, no personal media
/// (only TMDB posters chosen by the user), everything expires after 24h.
@Observable
final class StatusService {
    static let shared = StatusService()

    /// Statuses/comments hidden locally by the user ("Nascondi").
    private(set) var hiddenIds: Set<String>

    /// Quick emoji reactions allowed by the backend, in display order.
    static let allowedReactions: [String] = ["❤️", "🔥", "😂", "👀"]

    private static let hiddenKey = "status.hiddenIds"
    private let defaults = UserDefaults.standard

    private init() {
        hiddenIds = Set(UserDefaults.standard.stringArray(forKey: Self.hiddenKey) ?? [])
    }

    private var deviceId: String { CommunityService.shared.deviceId }
    private var nickname: String { CommunityService.shared.nickname }

    // MARK: - API

    /// Active statuses grouped per anonymous author (mine first, then unseen).
    func loadFeed() async throws -> [StatusGroup] {
        let payload: FeedPayload = try await get("/status/feed?deviceId=\(deviceId)")
        return payload.groups.compactMap { group in
            let visible = group.statuses.filter { !hiddenIds.contains($0.id) }
            guard !visible.isEmpty else { return nil }
            return StatusGroup(
                authorId: group.authorId,
                nickname: group.nickname,
                isMine: group.isMine,
                statuses: visible
            )
        }
    }

    /// Publishes a new status: TMDB movie + optional mood tag + short comment (max 150).
    func publish(movie: TMDBMovie, mood: Mood?, text: String) async throws -> MoodStatusItem {
        guard ContentModeration.isClean(text) else { throw CommunityError.offensive }
        var body: [String: Any] = [
            "deviceId": deviceId,
            "nickname": nickname,
            "movieId": movie.id,
            "movieTitle": movie.title,
            "text": text
        ]
        if let poster = movie.posterPath { body["posterPath"] = poster }
        if let mood { body["mood"] = mood.rawValue }
        let payload: StatusPayload = try await post("/status/publish", body: body)
        // Counts the action only: text and movie stay out of analytics.
        AnalyticsService.shared.log("status_posted")
        return payload.status
    }

    /// Records that this device saw a status (fire-and-forget friendly).
    func markViewed(statusId: String) async {
        let _: OkOnly? = try? await post("/status/view", body: [
            "deviceId": deviceId,
            "statusId": statusId
        ])
    }

    /// Public comments under a status, oldest first.
    func loadComments(statusId: String) async throws -> [StatusComment] {
        let payload: CommentsPayload = try await get("/status/comments?statusId=\(statusId)&deviceId=\(deviceId)")
        return payload.comments.filter { !hiddenIds.contains($0.id) }
    }

    /// Leaves a short public comment (max 100 characters).
    func sendComment(statusId: String, text: String) async throws -> StatusComment {
        guard ContentModeration.isClean(text) else { throw CommunityError.offensive }
        let payload: CommentPayload = try await post("/status/comment", body: [
            "deviceId": deviceId,
            "nickname": nickname,
            "statusId": statusId,
            "text": text
        ])
        AnalyticsService.shared.log("status_comment")
        return payload.comment
    }

    /// Toggles/replaces a quick emoji reaction; returns the fresh counts.
    func react(statusId: String, emoji: String) async throws -> (myReaction: String?, counts: [String: Int]) {
        let payload: ReactPayload = try await post("/status/react", body: [
            "deviceId": deviceId,
            "nickname": nickname,
            "statusId": statusId,
            "emoji": emoji
        ])
        return (payload.myReaction, payload.reactionCounts)
    }

    /// Owner-only recap: views, comments and reactions received.
    func loadInsights(statusId: String) async throws -> StatusInsights {
        try await get("/status/insights?deviceId=\(deviceId)&statusId=\(statusId)")
    }

    /// Reports a status or a comment (hidden for everyone after 3 reports).
    func report(targetType: String, targetId: String) async {
        let _: OkOnly? = try? await post("/status/report", body: [
            "deviceId": deviceId,
            "targetType": targetType,
            "targetId": targetId
        ])
    }

    /// Hides a status or comment locally (personal choice, no server call).
    func hide(id: String) {
        hiddenIds.insert(id)
        defaults.set(Array(hiddenIds), forKey: Self.hiddenKey)
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
            if let error = try? JSONDecoder().decode(StatusErrorPayload.self, from: data) {
                if error.code == "offensive" { throw CommunityError.offensive }
                if error.code == "rate_limited" { throw CommunityError.rateLimited }
            }
            throw CommunityError.network
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("[Status] Decoding error: \(error)")
            throw CommunityError.network
        }
    }
}

// MARK: - Payload wrappers

private nonisolated struct FeedPayload: Decodable { let groups: [StatusGroup] }
private nonisolated struct StatusPayload: Decodable { let status: MoodStatusItem }
private nonisolated struct CommentsPayload: Decodable { let comments: [StatusComment] }
private nonisolated struct CommentPayload: Decodable { let comment: StatusComment }
private nonisolated struct ReactPayload: Decodable {
    let ok: Bool
    let myReaction: String?
    let reactionCounts: [String: Int]
}
private nonisolated struct OkOnly: Decodable { let ok: Bool }
private nonisolated struct StatusErrorPayload: Decodable { let error: String; let code: String? }
