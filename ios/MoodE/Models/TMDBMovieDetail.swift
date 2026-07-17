//
//  TMDBMovieDetail.swift
//  MoodE
//

import Foundation

/// Full movie detail from TMDB, including credits and videos (append_to_response).
nonisolated struct TMDBMovieDetail: Codable {
    let id: Int
    let title: String
    let overview: String
    let runtime: Int?
    let releaseDate: String?
    let voteAverage: Double
    let posterPath: String?
    let backdropPath: String?
    let genres: [TMDBGenreInfo]
    let credits: TMDBCredits
    let videos: TMDBVideoList

    enum CodingKeys: String, CodingKey {
        case id, title, overview, runtime, genres, credits, videos
        case releaseDate = "release_date"
        case voteAverage = "vote_average"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
    }

    var releaseYear: String? {
        guard let releaseDate, releaseDate.count >= 4 else { return nil }
        return String(releaseDate.prefix(4))
    }

    /// Runtime formatted as "2h 15min".
    var formattedRuntime: String? {
        guard let runtime, runtime > 0 else { return nil }
        let hours = runtime / 60
        let minutes = runtime % 60
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)min" : "\(hours)h"
        }
        return "\(minutes)min"
    }

    /// Large poster URL (w780).
    var posterURL: URL? {
        guard let posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w780\(posterPath)")
    }

    /// Main cast (first 10 actors).
    var mainCast: [TMDBCastMember] {
        Array(credits.cast.prefix(10))
    }

    /// Best official YouTube trailer, falling back to any YouTube video.
    var trailer: TMDBVideo? {
        let youtube = videos.results.filter { $0.site == "YouTube" }
        let trailers = youtube.filter { $0.type == "Trailer" }
        return trailers.first(where: { $0.official })
            ?? trailers.first
            ?? youtube.first
    }
}

/// Genre info attached to a movie detail.
nonisolated struct TMDBGenreInfo: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
}

/// Credits payload (cast list).
nonisolated struct TMDBCredits: Codable {
    let cast: [TMDBCastMember]
}

/// Actor appearing in a movie.
nonisolated struct TMDBCastMember: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let character: String?
    let profilePath: String?

    enum CodingKeys: String, CodingKey {
        case id, name, character
        case profilePath = "profile_path"
    }

    /// Profile photo URL (w185).
    var profileURL: URL? {
        guard let profilePath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w185\(profilePath)")
    }
}

/// Videos payload (trailers, teasers, clips).
nonisolated struct TMDBVideoList: Codable {
    let results: [TMDBVideo]
}

/// Video attached to a movie (YouTube trailers etc.).
nonisolated struct TMDBVideo: Codable, Identifiable, Hashable {
    let id: String
    let key: String
    let name: String
    let site: String
    let type: String
    let official: Bool

    /// Embeddable YouTube player URL.
    var embedURL: URL? {
        URL(string: "https://www.youtube.com/embed/\(key)?playsinline=1&rel=0")
    }
}
