//
//  StatusModels.swift
//  MoodE
//

import Foundation

/// One ephemeral "Stato Mood": a favorite movie (TMDB poster + title,
/// never user-uploaded media) with an optional short comment.
/// Disappears automatically 24 hours after publication.
nonisolated struct MoodStatusItem: Codable, Identifiable, Hashable {
    let id: String
    let movieId: Int
    let movieTitle: String
    let posterPath: String?
    let text: String?
    /// Milliseconds since epoch (server clock).
    let createdAt: Double
    let expiresAt: Double
    /// Whether the requesting device has already seen this status.
    var seen: Bool
    var commentCount: Int
    /// Emoji -> count of quick reactions.
    var reactionCounts: [String: Int]
    /// Reaction left by the requesting device, if any.
    var myReaction: String?
    /// Views by others; present only on the owner's own statuses.
    let viewCount: Int?

    var date: Date { Date(timeIntervalSince1970: createdAt / 1000) }
    var expiryDate: Date { Date(timeIntervalSince1970: expiresAt / 1000) }

    var posterURL: URL? {
        guard let posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")
    }
}

/// All active statuses of one anonymous author (grouped like a story reel).
nonisolated struct StatusGroup: Codable, Identifiable, Hashable {
    /// Opaque random author id (never the device id).
    let authorId: String
    let nickname: String
    let isMine: Bool
    var statuses: [MoodStatusItem]

    var id: String { authorId }
    var hasUnseen: Bool { statuses.contains { !$0.seen } }
}

/// Short public comment left under a status.
nonisolated struct StatusComment: Codable, Identifiable, Hashable {
    let id: String
    let nickname: String
    let text: String
    let createdAt: Double
    let isMine: Bool

    var date: Date { Date(timeIntervalSince1970: createdAt / 1000) }
}

/// One quick emoji reaction, shown to the status owner with the
/// anonymous nickname of who reacted.
nonisolated struct StatusReactionEntry: Codable, Identifiable, Hashable {
    let nickname: String
    let emoji: String
    let createdAt: Double

    var id: String { "\(nickname)-\(emoji)-\(createdAt)" }
}

/// Owner-only recap of a status: views, comments and reactions received.
nonisolated struct StatusInsights: Codable {
    let viewCount: Int
    let commentCount: Int
    let reactions: [StatusReactionEntry]
}
