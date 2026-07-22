//
//  WatchProviderCache.swift
//  MoodE
//

import Foundation

/// Session cache for the streaming providers shown under movie cards.
/// Each movie id is fetched once (lightweight TMDB call), concurrent
/// requests for the same id share the in-flight task.
final class WatchProviderCache {
    static let shared = WatchProviderCache()

    private var cache: [Int: [TMDBWatchProvider]] = [:]
    private var inFlight: [Int: Task<[TMDBWatchProvider], Never>] = [:]

    private init() {}

    /// Streaming providers for the user's best region: subscription
    /// platforms first, rent/buy as fallback. Empty when unavailable.
    func providers(for movieId: Int) async -> [TMDBWatchProvider] {
        if let hit = cache[movieId] { return hit }
        if let running = inFlight[movieId] { return await running.value }

        let task = Task<[TMDBWatchProvider], Never> {
            guard let results = try? await TMDBService.movieWatchProviders(id: movieId) else {
                return []
            }
            guard let region = results.bestRegion else { return [] }
            let providers = region.flatrate ?? region.rent ?? region.buy ?? []
            return Array(providers.prefix(4))
        }
        inFlight[movieId] = task
        let value = await task.value
        inFlight[movieId] = nil
        cache[movieId] = value
        return value
    }
}
