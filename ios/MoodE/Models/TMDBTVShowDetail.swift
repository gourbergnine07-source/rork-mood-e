//
//  TMDBTVShowDetail.swift
//  MoodE
//

import Foundation

/// Full TV show detail from TMDB, including credits, videos, watch
/// providers and the next episode on air (append_to_response).
nonisolated struct TMDBTVShowDetail: Codable {
    let id: Int
    let name: String
    let overview: String
    let firstAirDate: String?
    let voteAverage: Double
    let posterPath: String?
    let backdropPath: String?
    let numberOfSeasons: Int?
    let numberOfEpisodes: Int?
    let genres: [TMDBGenreInfo]
    let credits: TMDBCredits
    let videos: TMDBVideoList
    let watchProviders: TMDBWatchProviderResults?
    let nextEpisodeToAir: TMDBTVEpisodeInfo?

    enum CodingKeys: String, CodingKey {
        case id, name, overview, genres, credits, videos
        case firstAirDate = "first_air_date"
        case voteAverage = "vote_average"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case numberOfSeasons = "number_of_seasons"
        case numberOfEpisodes = "number_of_episodes"
        case watchProviders = "watch/providers"
        case nextEpisodeToAir = "next_episode_to_air"
    }

    var firstAirYear: String? {
        guard let firstAirDate, firstAirDate.count >= 4 else { return nil }
        return String(firstAirDate.prefix(4))
    }

    /// Large poster URL (w780).
    var posterURL: URL? {
        guard let posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w780\(posterPath)")
    }

    /// Main cast (first 8 actors).
    var mainCast: [TMDBCastMember] {
        Array(credits.cast.prefix(8))
    }

    /// Best official YouTube trailer, falling back to any YouTube video.
    var trailer: TMDBVideo? {
        videos.bestTrailer
    }

    /// Copy with a replaced overview (used for the English fallback).
    func withOverview(_ overview: String) -> TMDBTVShowDetail {
        TMDBTVShowDetail(
            id: id,
            name: name,
            overview: overview,
            firstAirDate: firstAirDate,
            voteAverage: voteAverage,
            posterPath: posterPath,
            backdropPath: backdropPath,
            numberOfSeasons: numberOfSeasons,
            numberOfEpisodes: numberOfEpisodes,
            genres: genres,
            credits: credits,
            videos: videos,
            watchProviders: watchProviders,
            nextEpisodeToAir: nextEpisodeToAir
        )
    }
}
