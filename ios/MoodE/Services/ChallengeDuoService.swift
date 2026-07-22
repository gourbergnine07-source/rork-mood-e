//
//  ChallengeDuoService.swift
//  MoodE
//

import Foundation
import Supabase

/// Row of `challenge_duos`: an anonymous two-person run of the monthly
/// challenge, keyed by a shareable 6-digit code. Only the code and the two
/// progress counters travel to the cloud — no names, no accounts.
/// Rows expire automatically after ~40 days (RLS filter).
nonisolated struct ChallengeDuoRow: Codable, Sendable {
    let code: String
    let monthKey: String
    let hostProgress: Int
    let guestProgress: Int
    let guestJoined: Bool

    enum CodingKeys: String, CodingKey {
        case code
        case monthKey = "month_key"
        case hostProgress = "host_progress"
        case guestProgress = "guest_progress"
        case guestJoined = "guest_joined"
    }
}

private nonisolated struct ChallengeDuoInsert: Codable, Sendable {
    let code: String
    let monthKey: String

    enum CodingKeys: String, CodingKey {
        case code
        case monthKey = "month_key"
    }
}

/// Thin client for the shared monthly challenge (Supabase, anon key only).
/// Reuses `DuoRole` / `DuoError` from the duo-night sessions.
enum ChallengeDuoService {
    /// Creates a fresh pairing for the given month and returns its code.
    static func create(monthKey: String) async throws -> String {
        for _ in 0..<3 {
            let code = String(format: "%06d", Int.random(in: 0...999_999))
            do {
                try await SupabaseService.client
                    .from("challenge_duos")
                    .insert(ChallengeDuoInsert(code: code, monthKey: monthKey))
                    .execute()
                return code
            } catch {
                continue // code collision or transient error: retry
            }
        }
        throw DuoError.generic
    }

    /// Loads a pairing; throws `.notFound` for wrong or expired codes.
    static func fetch(code: String) async throws -> ChallengeDuoRow {
        let rows: [ChallengeDuoRow] = try await SupabaseService.client
            .from("challenge_duos")
            .select()
            .eq("code", value: code)
            .execute().value
        guard let row = rows.first else { throw DuoError.notFound }
        return row
    }

    /// Guest entry point: validates the code belongs to the current month's
    /// challenge and flags the join.
    static func join(code: String, monthKey: String) async throws -> ChallengeDuoRow {
        let row = try await fetch(code: code)
        guard row.monthKey == monthKey else { throw DuoError.notFound }
        try? await SupabaseService.client
            .from("challenge_duos")
            .update(["guest_joined": true])
            .eq("code", value: code)
            .execute()
        return row
    }

    /// Publishes this device's progress on its side of the pairing.
    static func updateProgress(code: String, role: DuoRole, value: Int) async throws {
        let payload: [String: Int] = role == .host
            ? ["host_progress": value]
            : ["guest_progress": value]
        try await SupabaseService.client
            .from("challenge_duos")
            .update(payload)
            .eq("code", value: code)
            .execute()
    }
}
