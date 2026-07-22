//
//  FriendStatsService.swift
//  MoodE
//

import Foundation
import Observation
import Supabase

/// Compact stats snapshot of one user, as stored in `friend_stats`.
/// Only aggregate numbers travel to the cloud — never movie titles,
/// notes or diary content.
nonisolated struct FriendStatsRow: Codable, Identifiable, Sendable, Equatable {
    let userId: String
    let displayName: String
    let friendCode: String?
    let watchedCount: Int
    let totalMinutes: Int
    let topGenreId: Int?
    let topDecade: Int?
    let streak: Int
    let bestStreak: Int

    var id: String { userId }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case displayName = "display_name"
        case friendCode = "friend_code"
        case watchedCount = "watched_count"
        case totalMinutes = "total_minutes"
        case topGenreId = "top_genre_id"
        case topDecade = "top_decade"
        case streak
        case bestStreak = "best_streak"
    }
}

/// Upsert payload for the caller's own snapshot. `friend_code` is omitted
/// on purpose: the database generates it once and it never changes.
nonisolated private struct FriendStatsUpsert: Encodable, Sendable {
    let userId: String
    let displayName: String
    let watchedCount: Int
    let totalMinutes: Int
    let topGenreId: Int?
    let topDecade: Int?
    let streak: Int
    let bestStreak: Int
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case displayName = "display_name"
        case watchedCount = "watched_count"
        case totalMinutes = "total_minutes"
        case topGenreId = "top_genre_id"
        case topDecade = "top_decade"
        case streak
        case bestStreak = "best_streak"
        case updatedAt = "updated_at"
    }
}

/// Minimal projection used when only the friend code is needed.
nonisolated private struct FriendCodeRow: Decodable, Sendable {
    let friendCode: String?

    enum CodingKeys: String, CodingKey {
        case friendCode = "friend_code"
    }
}

nonisolated private struct AddFriendResult: Decodable, Sendable {
    let friendUserId: String
    let friendName: String

    enum CodingKeys: String, CodingKey {
        case friendUserId = "friend_user_id"
        case friendName = "friend_name"
    }
}

/// Errors surfaced by the add-friend flow, mapped to friendly messages.
enum FriendAddError: Error {
    case codeNotFound
    case ownCode
    case generic
}

/// Friends & stats comparison engine. The device pushes an aggregate
/// snapshot of the local stats to `friend_stats`; RLS makes each snapshot
/// visible only to its owner and to linked friends. Friend links are
/// created by exchanging short friend codes.
@Observable
final class FriendStatsService {
    static let shared = FriendStatsService()

    /// My friend code, fetched after the first snapshot push.
    private(set) var myCode: String?
    /// Linked friends with their latest snapshots.
    private(set) var friends: [FriendStatsRow] = []
    private(set) var isLoading = false
    private(set) var lastError = false

    private init() {}

    /// Pushes the local snapshot and reloads the friends list.
    func refresh(auth: AuthManager, snapshot: FriendStatsRow) async {
        guard !isLoading, let user = auth.user else { return }
        isLoading = true
        lastError = false
        defer { isLoading = false }

        do {
            await auth.ensureValidToken()
            guard auth.user != nil else {
                lastError = true
                return
            }
            let supabase = SupabaseService.client

            try await supabase.from("friend_stats").upsert(
                FriendStatsUpsert(
                    userId: user.id,
                    displayName: snapshot.displayName,
                    watchedCount: snapshot.watchedCount,
                    totalMinutes: snapshot.totalMinutes,
                    topGenreId: snapshot.topGenreId,
                    topDecade: snapshot.topDecade,
                    streak: snapshot.streak,
                    bestStreak: snapshot.bestStreak,
                    updatedAt: Date()
                )
            ).execute()

            // RLS returns my row plus every linked friend's row.
            let rows: [FriendStatsRow] = try await supabase
                .from("friend_stats").select()
                .execute().value

            myCode = rows.first(where: { $0.userId == user.id })?.friendCode
            friends = rows
                .filter { $0.userId != user.id }
                .sorted { $0.watchedCount > $1.watchedCount }
        } catch {
            print("FriendStats: refresh failed: \(error.localizedDescription)")
            lastError = true
        }
    }

    /// Returns my friend code, creating the cloud row on first use so the
    /// database can generate one. Used by the invite-friends flow, which
    /// may run before the full stats snapshot is ever pushed.
    func ensureCode(auth: AuthManager, displayName: String) async -> String? {
        if let myCode { return myCode }
        await auth.ensureValidToken()
        guard let user = auth.user else { return nil }

        do {
            let supabase = SupabaseService.client

            let existing: [FriendCodeRow] = try await supabase
                .from("friend_stats")
                .select("friend_code")
                .eq("user_id", value: user.id)
                .execute().value
            if let code = existing.first?.friendCode {
                myCode = code
                return code
            }

            // No row yet: insert a zeroed snapshot; the DB generates the code.
            try await supabase.from("friend_stats").upsert(
                FriendStatsUpsert(
                    userId: user.id,
                    displayName: displayName,
                    watchedCount: 0,
                    totalMinutes: 0,
                    topGenreId: nil,
                    topDecade: nil,
                    streak: 0,
                    bestStreak: 0,
                    updatedAt: Date()
                ),
                onConflict: "user_id",
                ignoreDuplicates: true
            ).execute()

            let created: [FriendCodeRow] = try await supabase
                .from("friend_stats")
                .select("friend_code")
                .eq("user_id", value: user.id)
                .execute().value
            myCode = created.first?.friendCode
            return myCode
        } catch {
            print("FriendStats: ensureCode failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Links both users from a friend code. Returns the new friend's name.
    func addFriend(code: String, auth: AuthManager) async throws -> String {
        await auth.ensureValidToken()
        guard auth.user != nil else { throw FriendAddError.generic }

        do {
            let results: [AddFriendResult] = try await SupabaseService.client
                .rpc("add_friend_by_code", params: ["code": code])
                .execute().value
            guard let friend = results.first else { throw FriendAddError.generic }
            AnalyticsService.shared.log("friend_added")
            return friend.friendName
        } catch {
            let message = error.localizedDescription
            if message.contains("CODE_NOT_FOUND") { throw FriendAddError.codeNotFound }
            if message.contains("OWN_CODE") { throw FriendAddError.ownCode }
            throw FriendAddError.generic
        }
    }

    /// Removes the mutual link; the friend disappears from both lists.
    func removeFriend(userId: String, auth: AuthManager) async {
        guard let me = auth.user?.id else { return }
        do {
            await auth.ensureValidToken()
            try await SupabaseService.client
                .from("friends")
                .delete()
                .or("and(user_id.eq.\(me),friend_id.eq.\(userId)),and(user_id.eq.\(userId),friend_id.eq.\(me))")
                .execute()
            friends.removeAll { $0.userId == userId }
        } catch {
            print("FriendStats: remove failed: \(error.localizedDescription)")
        }
    }
}
