//
//  AdviceModels.swift
//  MoodE
//

import Foundation

/// Public, anonymous advice request published on the community board.
nonisolated struct AdviceRequest: Codable, Identifiable, Hashable {
    let id: String
    let nickname: String
    let mood: String
    let text: String
    /// Milliseconds since epoch (server clock).
    let createdAt: Double
    let replyCount: Int
    let isMine: Bool

    var date: Date { Date(timeIntervalSince1970: createdAt / 1000) }
    var moodValue: Mood? { Mood(rawValue: mood) }
}

/// A movie suggestion left under an advice request.
nonisolated struct AdviceReply: Codable, Identifiable, Hashable {
    let id: String
    let nickname: String
    let movieId: Int
    let movieTitle: String
    let posterPath: String?
    let text: String?
    let createdAt: Double
    let helpfulCount: Int
    let isMine: Bool
    let markedHelpful: Bool

    var date: Date { Date(timeIntervalSince1970: createdAt / 1000) }
    var posterURL: URL? {
        guard let posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w185\(posterPath)")
    }
}

/// Personal community counters, visible only to the user.
nonisolated struct CommunityProfile: Codable {
    var helpfulReceived: Int
    var requestsPublished: Int
    var repliesGiven: Int

    static let empty = CommunityProfile(helpfulReceived: 0, requestsPublished: 0, repliesGiven: 0)
}

/// Full detail payload: the request plus its replies.
nonisolated struct AdviceDetail: Codable {
    let request: AdviceRequest
    let replies: [AdviceReply]
}
