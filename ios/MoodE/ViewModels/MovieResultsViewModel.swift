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
        "recommendations.\(String(describing: selection.mood)).\(String(describing: selection.goal)).\(String(describing: selection.era))"
    }

    /// Fetches the first batch of recommendations for the given flow selection.
    /// Serves the local cache when fresh (< 6h); otherwise shows cached data
    /// instantly and refreshes in background.
    func load(selection: MoodSelection, excluding excludedIds: Set<Int> = [], forceRefresh: Bool = false) async {
        if !forceRefresh,
           let disk = TMDBCache.load(RecommendationsSnapshot.self, forKey: Self.cacheKey(for: selection)) {
            let movies = disk.value.movies.filter { !excludedIds.contains($0.id) }
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
        await fetch(selection: selection, startPage: 1, excluding: excludedIds)
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
        await fetch(selection: selection, startPage: 1, excluding: excludedIds)
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

        do {
            var bonus: [TMDBMovie] = []
            var page = currentPage
            var fetches = 0

            while bonus.count < 5 && fetches < 3 {
                page = page >= totalPages ? 1 : page + 1
                let response = try await TMDBService.discoverMovies(for: selection, page: page)
                currentPage = response.page
                totalPages = max(response.totalPages, 1)
                fetches += 1

                let fresh = response.results.filter { movie in
                    !excludedIds.contains(movie.id)
                        && !current.contains(where: { $0.id == movie.id })
                        && !bonus.contains(where: { $0.id == movie.id })
                }
                bonus += fresh

                if page == 1 { break }
            }

            guard !bonus.isEmpty else { return }
            state = .loaded(current + Array(bonus.prefix(5)))
        } catch {
            print("MovieResultsViewModel: bonus non caricato: \(error.localizedDescription)")
        }
    }

    /// Fetches pages starting at `startPage`, filtering out watched movies and
    /// pulling additional pages until the batch is full enough.
    private func fetch(selection: MoodSelection, startPage: Int, excluding excludedIds: Set<Int>) async {
        do {
            var collected: [TMDBMovie] = []
            var page = startPage
            var fetches = 0

            repeat {
                let response = try await TMDBService.discoverMovies(for: selection, page: page)
                currentPage = response.page
                totalPages = max(response.totalPages, 1)
                fetches += 1

                let fresh = response.results.filter { movie in
                    !excludedIds.contains(movie.id)
                        && !collected.contains(where: { $0.id == movie.id })
                }
                collected += fresh

                guard collected.count < minBatchSize,
                      currentPage < totalPages,
                      fetches < maxPageFetches else { break }
                page = currentPage + 1
            } while true

            let batch = Array(collected.prefix(batchSize))
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
