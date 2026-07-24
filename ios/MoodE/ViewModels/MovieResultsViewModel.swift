//
//  MovieResultsViewModel.swift
//  MoodE
//

import Foundation
import Observation

/// Snapshot of a results batch persisted in the local cache.
nonisolated struct RecommendationsSnapshot: Codable {
    let movies: [TMDBMovie]
    let page: Int
    let totalPages: Int
}

/// Loads mood-based movie recommendations from TMDB for the results screen,
/// with support for fresh batches via discover pagination.
/// Movies already marked as watched are excluded; extra pages are fetched
/// automatically to keep the batch full.
@Observable
final class MovieResultsViewModel {
    enum LoadState {
        case loading
        case loaded([TMDBMovie])
        case failed(String)
    }

    private(set) var state: LoadState = .loading
    private(set) var isRefreshing: Bool = false
    /// True while the rewarded-ad bonus batch is being fetched.
    private(set) var isLoadingBonus: Bool = false
    /// Incremented on every successful batch, used to scroll back to top.
    private(set) var batchId: Int = 0

    private var currentPage: Int = 1
    private var totalPages: Int = 1

    /// Maximum number of movies shown per batch.
    private let batchSize = 15
    /// Minimum acceptable batch before topping up with extra pages.
    private let minBatchSize = 10
    /// Safety cap on extra page fetches per batch.
    private let maxPageFetches = 4

    private static func cacheKey(for selection: MoodSelection) -> String {
        var key = "recommendations.v2.\(String(describing: selection.mood)).\(String(describing: selection.goal)).\(String(describing: selection.era))"
        // Pool generation: a biweekly renewal starts a fresh cache bucket,
        // so the rotated discover pages actually reach the screen.
        key += ".r\(PoolRotation.shared.currentOffset)"
        // Separate cache bucket per streaming-filter configuration, so
        // toggling the filter never serves a stale unfiltered batch.
        let store = StreamingServicesStore.shared
        if store.isFilterActive {
            key += ".only." + store.selectedIds.sorted().joined(separator: "-")
        }
        return key
    }

    /// When the streaming filter is on, keeps only movies available on one
    /// of the user's selected subscription services (JustWatch flatrate
    /// data, fetched concurrently and cached per movie).
    private func filterToSelectedServices(_ movies: [TMDBMovie]) async -> [TMDBMovie] {
        guard StreamingServicesStore.shared.isFilterActive, !movies.isEmpty else { return movies }
        var matching: Set<Int> = []
        await withTaskGroup(of: (Int, Bool).self) { group in
            for movie in movies {
                let movieId = movie.id
                group.addTask { @MainActor in
                    let flatrate = await WatchProviderCache.shared.flatrateProviders(for: movieId)
                    return (movieId, StreamingServicesStore.shared.matchesAny(of: flatrate))
                }
            }
            for await (id, matches) in group where matches {
                matching.insert(id)
            }
        }
        return movies.filter { matching.contains($0.id) }
    }

    /// Fetches the first batch of recommendations for the given flow selection.
    /// Serves the local cache when fresh (< 6h); otherwise shows cached data
    /// instantly and refreshes in background.
    func load(selection: MoodSelection, excluding excludedIds: Set<Int> = [], forceRefresh: Bool = false) async {
        if !forceRefresh,
           let disk = TMDBCache.load(RecommendationsSnapshot.self, forKey: Self.cacheKey(for: selection)) {
            let crossMood = RecommendationRegistry.shared.excludedIds(for: selection.mood)
            let movies = disk.value.movies.filter { !excludedIds.contains($0.id) && !crossMood.contains($0.id) }
            if !movies.isEmpty {
                currentPage = disk.value.page
                totalPages = disk.value.totalPages
                state = .loaded(movies)
                if disk.isFresh { return }
            }
        }

        if case .loaded = state {
            // Cached batch already on screen: refresh silently.
        } else {
            state = .loading
        }
        currentPage = 1
        await fetch(selection: selection, startPage: 1 + PoolRotation.shared.currentOffset, excluding: excludedIds)
    }

    /// Silent refresh triggered when the app returns to the foreground:
    /// hits the API only if the cached batch is older than 6 hours.
    func refreshIfStale(selection: MoodSelection, excluding excludedIds: Set<Int> = []) async {
        guard !isRefreshing else { return }
        if let disk = TMDBCache.load(RecommendationsSnapshot.self, forKey: Self.cacheKey(for: selection)),
           disk.isFresh {
            return
        }
        guard case .loaded = state else { return }
        await fetch(selection: selection, startPage: 1 + PoolRotation.shared.currentOffset, excluding: excludedIds)
    }

    /// Fetches a fresh batch (next discover page) keeping the same filters.
    /// Wraps back to page 1 after the last available page.
    func loadNewBatch(selection: MoodSelection, excluding excludedIds: Set<Int> = []) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        let nextPage = currentPage >= totalPages ? 1 : currentPage + 1
        await fetch(selection: selection, startPage: nextPage, excluding: excludedIds)
        isRefreshing = false
    }

    /// Appends up to 5 extra picks (from the next discover pages) after the
    /// user watched a rewarded ad. Keeps the current batch on screen and does
    /// not touch the cache, so the base recommendations stay stable.
    func loadBonusMovies(selection: MoodSelection, excluding excludedIds: Set<Int> = []) async {
        guard case .loaded(let current) = state, !isLoadingBonus else { return }
        isLoadingBonus = true
        defer { isLoadingBonus = false }

        let excluded = excludedIds.union(RecommendationRegistry.shared.excludedIds(for: selection.mood))
        let recentlyShown = RecommendationRegistry.shared.recentlyShownIds().subtracting(excluded)

        do {
            var bonus: [TMDBMovie] = []
            var recentFallback: [TMDBMovie] = []
            var page = currentPage
            var fetches = 0

            while bonus.count < 5 && fetches < 3 {
                page = page >= totalPages ? 1 : page + 1
                let response = try await TMDBService.discoverMovies(for: selection, page: page)
                currentPage = response.page
                totalPages = max(response.totalPages, 1)
                fetches += 1

                let unseen = response.results.filter { movie in
                    !excluded.contains(movie.id)
                        && !current.contains(where: { $0.id == movie.id })
                        && !bonus.contains(where: { $0.id == movie.id })
                        && !recentFallback.contains(where: { $0.id == movie.id })
                }
                let fresh = unseen.filter { !recentlyShown.contains($0.id) }
                recentFallback += unseen.filter { recentlyShown.contains($0.id) }
                bonus += await filterToSelectedServices(fresh)

                if page == 1 { break }
            }

            // Pool ran dry: a light repeat beats no bonus after a rewarded ad.
            if bonus.isEmpty, !recentFallback.isEmpty {
                bonus = await filterToSelectedServices(recentFallback)
            }

            guard !bonus.isEmpty else { return }
            let bonusBatch = Array(bonus.prefix(5))
            RecommendationRegistry.shared.register(bonusBatch, for: selection.mood)
            state = .loaded(current + bonusBatch)
        } catch {
            print("MovieResultsViewModel: bonus non caricato: \(error.localizedDescription)")
        }
    }

    /// Fetches pages starting at `startPage`, filtering out watched movies and
    /// pulling additional pages until the batch is full enough.
    private func fetch(selection: MoodSelection, startPage: Int, excluding excludedIds: Set<Int>) async {
        // HARD exclusions, never re-proposed: watched movies (passed by the
        // caller) + titles recently assigned to a DIFFERENT emotion.
        let excluded = excludedIds.union(RecommendationRegistry.shared.excludedIds(for: selection.mood))
        // SOFT exclusion: anything shown in recommendations in the last 7
        // days. Skipped first, allowed back only if the pool runs too dry.
        let recentlyShown = RecommendationRegistry.shared.recentlyShownIds().subtracting(excluded)
        do {
            var collected: [TMDBMovie] = []
            var recentFallback: [TMDBMovie] = []
            var page = startPage
            var fetches = 0
            var didRewind = false

            repeat {
                let response = try await TMDBService.discoverMovies(for: selection, page: page)
                currentPage = response.page
                totalPages = max(response.totalPages, 1)
                fetches += 1

                // The rotated start page can overshoot a small pool: rewind
                // once to page 1 so narrow combos still fill up.
                if response.results.isEmpty, page > totalPages, page > 1, !didRewind {
                    didRewind = true
                    page = 1
                    continue
                }

                let unseen = response.results.filter { movie in
                    !excluded.contains(movie.id)
                        && !collected.contains(where: { $0.id == movie.id })
                        && !recentFallback.contains(where: { $0.id == movie.id })
                }
                let fresh = unseen.filter { !recentlyShown.contains($0.id) }
                recentFallback += unseen.filter { recentlyShown.contains($0.id) }
                collected += await filterToSelectedServices(fresh)

                // The streaming filter discards many titles per page, so it
                // gets a slightly higher page budget to fill the batch.
                let pageCap = StreamingServicesStore.shared.isFilterActive ? 6 : maxPageFetches
                guard collected.count < minBatchSize,
                      currentPage < totalPages,
                      fetches < pageCap else { break }
                page = currentPage + 1
            } while true

            // Narrow mood × goal queries can run dry: top up with the
            // broader (relaxed) query so the batch is never empty.
            if collected.count < 5 {
                var relaxedPage = 1
                while collected.count < minBatchSize && relaxedPage <= 2 {
                    let response = try await TMDBService.discoverMovies(for: selection, page: relaxedPage, relaxed: true)
                    let unseen = response.results.filter { movie in
                        !excluded.contains(movie.id)
                            && !collected.contains(where: { $0.id == movie.id })
                            && !recentFallback.contains(where: { $0.id == movie.id })
                    }
                    let fresh = unseen.filter { !recentlyShown.contains($0.id) }
                    recentFallback += unseen.filter { recentlyShown.contains($0.id) }
                    collected += await filterToSelectedServices(fresh)
                    if response.page >= response.totalPages { break }
                    relaxedPage += 1
                }
            }

            // Very specific combos can drop under 5 titles once watched and
            // recently shown movies are removed: exceptionally re-admit the
            // recently shown ones (never the watched ones) — a light repeat
            // beats an empty result.
            if collected.count < 5, !recentFallback.isEmpty {
                let refill = await filterToSelectedServices(recentFallback)
                collected += refill.prefix(minBatchSize - collected.count)
            }

            // Light spectator-profile boost: refines, never replaces, the flow.
            let batch = QuizStore.rerank(Array(collected.prefix(batchSize)))
            RecommendationRegistry.shared.register(batch, for: selection.mood)
            state = .loaded(batch)
            batchId += 1
            TMDBCache.save(
                RecommendationsSnapshot(movies: batch, page: currentPage, totalPages: totalPages),
                forKey: Self.cacheKey(for: selection)
            )
        } catch {
            if case .loaded(let current) = state, !current.isEmpty {
                // Keep showing the current batch when a refresh fails.
                return
            }
            let message = (error as? TMDBError)?.errorDescription ?? L("error.generic")
            state = .failed(message)
        }
    }
}
