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

    /// Cached availability: the short strip shown under the card plus
    /// the raw subscription list used for the "Available now" badge.
    struct Availability {
        let strip: [TMDBWatchProvider]
        let flatrate: [TMDBWatchProvider]

        static let empty = Availability(strip: [], flatrate: [])
    }

    private var cache: [Int: Availability] = [:]
    private var inFlight: [Int: Task<Availability, Never>] = [:]

    /// TV shows live in a separate namespace: TMDB movie and TV ids overlap.
    private var tvCache: [Int: Availability] = [:]
    private var tvInFlight: [Int: Task<Availability, Never>] = [:]

    private init() {}

    /// Streaming providers for the user's best region: subscription
    /// platforms first, rent/buy as fallback. Empty when unavailable.
    func providers(for movieId: Int) async -> [TMDBWatchProvider] {
        await availability(for: movieId).strip
    }

    /// Subscription-only providers (flatrate) for the badge match.
    func flatrateProviders(for movieId: Int) async -> [TMDBWatchProvider] {
        await availability(for: movieId).flatrate
    }

    /// Streaming providers for a TV show (same region logic as movies).
    func tvProviders(for showId: Int) async -> [TMDBWatchProvider] {
        await tvAvailability(for: showId).strip
    }

    private func tvAvailability(for showId: Int) async -> Availability {
        if let hit = tvCache[showId] { return hit }
        if let running = tvInFlight[showId] { return await running.value }

        let task = Task<Availability, Never> {
            guard let results = try? await TMDBService.tvWatchProviders(id: showId),
                  let region = results.bestRegion else {
                return .empty
            }
            let flatrate = region.flatrate ?? []
            let strip = flatrate.isEmpty ? (region.rent ?? region.buy ?? []) : flatrate
            return Availability(strip: Array(strip.prefix(4)), flatrate: flatrate)
        }
        tvInFlight[showId] = task
        let value = await task.value
        tvInFlight[showId] = nil
        tvCache[showId] = value
        return value
    }

    private func availability(for movieId: Int) async -> Availability {
        if let hit = cache[movieId] { return hit }
        if let running = inFlight[movieId] { return await running.value }

        let task = Task<Availability, Never> {
            guard let results = try? await TMDBService.movieWatchProviders(id: movieId),
                  let region = results.bestRegion else {
                return .empty
            }
            let flatrate = region.flatrate ?? []
            let strip = flatrate.isEmpty ? (region.rent ?? region.buy ?? []) : flatrate
            return Availability(strip: Array(strip.prefix(4)), flatrate: flatrate)
        }
        inFlight[movieId] = task
        let value = await task.value
        inFlight[movieId] = nil
        cache[movieId] = value
        return value
    }
}
