//
//  TVNextEpisodeCache.swift
//  MoodE
//

import Foundation

/// Session cache for the next-episode info shown on TV show cards in the
/// "In diffusione oggi" / "In corso di diffusione" categories. Each show id
/// is fetched once (lightweight TMDB call); concurrent requests for the
/// same id share the in-flight task.
final class TVNextEpisodeCache {
    static let shared = TVNextEpisodeCache()

    private var cache: [Int: TMDBTVEpisodeInfo?] = [:]
    private var inFlight: [Int: Task<TMDBTVEpisodeInfo?, Never>] = [:]

    private init() {}

    /// Next episode on air for the show, or nil when TMDB has none.
    func nextEpisode(for showId: Int) async -> TMDBTVEpisodeInfo? {
        if let hit = cache[showId] { return hit }
        if let running = inFlight[showId] { return await running.value }

        let task = Task<TMDBTVEpisodeInfo?, Never> {
            (try? await TMDBService.tvNextEpisode(id: showId)) ?? nil
        }
        inFlight[showId] = task
        let value = await task.value
        inFlight[showId] = nil
        cache[showId] = value
        return value
    }
}
