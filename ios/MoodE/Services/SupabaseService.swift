//
//  SupabaseService.swift
//  MoodE
//

import Foundation
import Supabase

/// Shared Supabase client. The accessToken closure hands the Rork Auth JWT
/// to PostgREST so Row Level Security sees the signed-in user; when signed
/// out it returns nil and requests run as the anonymous role.
enum SupabaseService {
    static let client = SupabaseClient(
        supabaseURL: URL(string: Config.EXPO_PUBLIC_SUPABASE_URL) ?? URL(string: "https://invalid.supabase.co")!,
        supabaseKey: Config.EXPO_PUBLIC_SUPABASE_ANON_KEY,
        options: .init(
            auth: .init(
                accessToken: {
                    KeychainHelper.get("access_token")
                }
            )
        )
    )
}

// MARK: - Remote row models (snake_case tables)

nonisolated struct ProfileUpsert: Encodable, Sendable {
    let id: String
    let email: String?
    let name: String?
}

/// Row of `diary_check_ins`; mirrors the local `MoodCheckIn`.
nonisolated struct RemoteCheckIn: Codable, Sendable {
    let id: UUID
    let userId: String
    let date: Date
    let moodRaw: String
    let goalRaw: String
    let eraRaw: String
    let isQuickPick: Bool
    let note: String?
    let proposed: [ProposedMovie]

    enum CodingKeys: String, CodingKey {
        case id, date, note, proposed
        case userId = "user_id"
        case moodRaw = "mood_raw"
        case goalRaw = "goal_raw"
        case eraRaw = "era_raw"
        case isQuickPick = "is_quick_pick"
    }

    init(from checkIn: MoodCheckIn, userId: String) {
        self.id = checkIn.id
        self.userId = userId
        self.date = checkIn.date
        self.moodRaw = checkIn.moodRaw
        self.goalRaw = checkIn.goalRaw
        self.eraRaw = checkIn.eraRaw
        self.isQuickPick = checkIn.isQuickPick
        self.note = checkIn.note
        self.proposed = checkIn.proposed
    }

    var asLocal: MoodCheckIn {
        MoodCheckIn(
            id: id,
            date: date,
            moodRaw: moodRaw,
            goalRaw: goalRaw,
            eraRaw: eraRaw,
            isQuickPick: isQuickPick,
            proposed: proposed,
            note: note
        )
    }
}

/// Row of `library_entries`; mirrors the local `LibraryEntry`.
nonisolated struct RemoteLibraryEntry: Codable, Sendable {
    let userId: String
    let movieId: Int
    let title: String
    let posterPath: String?
    let status: String
    let addedDate: Date
    let watchedDate: Date?

    enum CodingKeys: String, CodingKey {
        case title, status
        case userId = "user_id"
        case movieId = "movie_id"
        case posterPath = "poster_path"
        case addedDate = "added_date"
        case watchedDate = "watched_date"
    }

    init(from entry: LibraryEntry, userId: String) {
        self.userId = userId
        self.movieId = entry.id
        self.title = entry.title
        self.posterPath = entry.posterPath
        self.status = entry.status.rawValue
        self.addedDate = entry.addedDate
        self.watchedDate = entry.watchedDate
    }

    var asLocal: LibraryEntry? {
        guard let parsedStatus = LibraryStatus(rawValue: status) else { return nil }
        return LibraryEntry(
            id: movieId,
            title: title,
            posterPath: posterPath,
            status: parsedStatus,
            addedDate: addedDate,
            watchedDate: watchedDate
        )
    }
}

/// Row of `planner_scheduled`; mirrors the local `ScheduledMovie`.
nonisolated struct RemoteScheduled: Codable, Sendable {
    let id: UUID
    let userId: String
    let movieId: Int
    let title: String
    let posterPath: String?
    let genreIds: [Int]?
    let day: Date

    enum CodingKeys: String, CodingKey {
        case id, title, day
        case userId = "user_id"
        case movieId = "movie_id"
        case posterPath = "poster_path"
        case genreIds = "genre_ids"
    }

    init(from plan: ScheduledMovie, userId: String) {
        self.id = plan.id
        self.userId = userId
        self.movieId = plan.movieId
        self.title = plan.title
        self.posterPath = plan.posterPath
        self.genreIds = plan.genreIds
        self.day = plan.day
    }

    var asLocal: ScheduledMovie {
        ScheduledMovie(
            id: id,
            movieId: movieId,
            title: title,
            posterPath: posterPath,
            genreIds: genreIds,
            day: day
        )
    }
}

/// Row of `planner_memories`; mirrors the local `MovieMemory`.
nonisolated struct RemoteMemory: Codable, Sendable {
    let id: UUID
    let userId: String
    let movieId: Int
    let title: String
    let posterPath: String?
    let genreIds: [Int]?
    let watchedDate: Date
    let rating: Int
    let comment: String?

    enum CodingKeys: String, CodingKey {
        case id, title, rating, comment
        case userId = "user_id"
        case movieId = "movie_id"
        case posterPath = "poster_path"
        case genreIds = "genre_ids"
        case watchedDate = "watched_date"
    }

    init(from memory: MovieMemory, userId: String) {
        self.id = memory.id
        self.userId = userId
        self.movieId = memory.movieId
        self.title = memory.title
        self.posterPath = memory.posterPath
        self.genreIds = memory.genreIds
        self.watchedDate = memory.watchedDate
        self.rating = memory.rating
        self.comment = memory.comment
    }

    var asLocal: MovieMemory {
        MovieMemory(
            id: id,
            movieId: movieId,
            title: title,
            posterPath: posterPath,
            genreIds: genreIds,
            watchedDate: watchedDate,
            rating: rating,
            comment: comment
        )
    }
}
