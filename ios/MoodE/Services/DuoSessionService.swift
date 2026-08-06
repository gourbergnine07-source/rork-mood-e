//
//  DuoSessionService.swift
//  MoodE
//

import Foundation
import Supabase

/// Row of `duo_sessions`: a temporary, anonymous two-person session keyed
/// by a 6-digit code. Only mood/goal ids and the optional display name each
/// person chooses to share travel to the cloud — no accounts. Rows expire
/// automatically after 2 hours (RLS filter).
nonisolated struct DuoSessionRow: Codable, Sendable {
    let code: String
    let hostMood: String?
    let hostGoal: String?
    let hostName: String?
    let guestJoined: Bool
    let guestMood: String?
    let guestGoal: String?
    let guestName: String?

    enum CodingKeys: String, CodingKey {
        case code
        case hostMood = "host_mood"
        case hostGoal = "host_goal"
        case hostName = "host_name"
        case guestJoined = "guest_joined"
        case guestMood = "guest_mood"
        case guestGoal = "guest_goal"
        case guestName = "guest_name"
    }

    /// True when both people confirmed their mood + goal.
    var isReady: Bool {
        hostMood != nil && hostGoal != nil && guestMood != nil && guestGoal != nil
    }
}

/// Which side of the duo session this device is.
enum DuoRole {
    case host
    case guest
}

enum DuoError: Error {
    case notFound
    case generic
}

/// Guest-side join payload: flags the join and optionally shares a name.
private nonisolated struct DuoGuestJoinUpdate: Encodable, Sendable {
    let guestJoined: Bool
    let guestName: String?

    enum CodingKeys: String, CodingKey {
        case guestJoined = "guest_joined"
        case guestName = "guest_name"
    }
}

/// Thin client for the anonymous duo sessions (Supabase, anon key only).
enum DuoSessionService {
    /// Creates a fresh session and returns its 6-digit code. `name` is the
    /// optional display name the host chose to share with the friend.
    static func create(name: String? = nil) async throws -> String {
        for _ in 0..<3 {
            let code = String(format: "%06d", Int.random(in: 0...999_999))
            var payload = ["code": code]
            if let name, !name.isEmpty { payload["host_name"] = name }
            do {
                try await SupabaseService.client
                    .from("duo_sessions")
                    .insert(payload)
                    .execute()
                return code
            } catch {
                continue // code collision or transient error: retry
            }
        }
        throw DuoError.generic
    }

    /// Loads a session; throws `.notFound` for wrong or expired codes.
    static func fetch(code: String) async throws -> DuoSessionRow {
        let rows: [DuoSessionRow] = try await SupabaseService.client
            .from("duo_sessions")
            .select()
            .eq("code", value: code)
            .execute().value
        guard let row = rows.first else { throw DuoError.notFound }
        return row
    }

    /// Guest entry point: validates the code, flags the join and shares the
    /// optional display name.
    static func join(code: String, name: String? = nil) async throws -> DuoSessionRow {
        let row = try await fetch(code: code)
        let shared = (name?.isEmpty == false) ? name : nil
        try? await SupabaseService.client
            .from("duo_sessions")
            .update(DuoGuestJoinUpdate(guestJoined: true, guestName: shared))
            .eq("code", value: code)
            .execute()
        return row
    }

    /// Saves this device's mood + goal on its side of the session.
    static func submit(code: String, role: DuoRole, mood: Mood, goal: ViewingGoal) async throws {
        let payload: [String: String] = role == .host
            ? ["host_mood": mood.rawValue, "host_goal": goal.rawValue]
            : ["guest_mood": mood.rawValue, "guest_goal": goal.rawValue]
        try await SupabaseService.client
            .from("duo_sessions")
            .update(payload)
            .eq("code", value: code)
            .execute()
    }
}
