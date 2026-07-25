//
//  TVShowsViewModel.swift
//  MoodE
//

import Foundation
import Observation

/// Loads the TMDB TV lists for the "Emissioni televisive" section,
/// backed by the shared 6-hour local cache and silent refreshes.
@Observable
final class TVShowsViewModel {
    enum State {
        case idle
        case loading
        case loaded([TMDBTVShow])
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var isRefreshing = false
    var category: TVCategory = .popular

    /// In-memory cache per category so switching the selector is instant.
    private var memoryCache: [TVCategory: [TMDBTVShow]] = [:]

    private func cacheKey(for category: TVCategory) -> String {
        "tv.\(category.rawValue)"
    }

    /// Serves the local cache when fresh (< 6h), otherwise shows cached
    /// data instantly and refreshes in background.
    func load(forceRefresh: Bool = false) async {
        let category = self.category

        if !forceRefresh {
            if let cached = memoryCache[category] {
                state = .loaded(cached)
                return
            }
            if let disk = TMDBCache.load([TMDBTVShow].self, forKey: cacheKey(for: category)) {
                memoryCache[category] = disk.value
                state = .loaded(disk.value)
                if disk.isFresh { return }
                await refresh(category: category)
                return
            }
        }

        if memoryCache[category] == nil {
            state = .loading
        }
        await refresh(category: category)
    }

    /// Full reload after a language change: clears the per-category memory
    /// cache so every category refetches data localized in the new language.
    func reloadForLanguage() async {
        memoryCache.removeAll()
        state = .loading
        await load(forceRefresh: true)
    }

    /// Silent refresh on foreground: hits the API only if stale (> 6h).
    func refreshIfStale() async {
        let category = self.category
        if let disk = TMDBCache.load([TMDBTVShow].self, forKey: cacheKey(for: category)), disk.isFresh {
            return
        }
        guard !isRefreshing else { return }
        await refresh(category: category)
    }

    private func refresh(category: TVCategory) async {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let shows = try await TMDBService.tvShows(category: category).results
            memoryCache[category] = shows
            TMDBCache.save(shows, forKey: cacheKey(for: category))
            guard self.category == category else { return }
            state = .loaded(shows)
        } catch {
            guard self.category == category else { return }
            if let cached = memoryCache[category] {
                state = .loaded(cached)
            } else {
                let message = (error as? TMDBError)?.errorDescription ?? L("error.generic")
                state = .failed(message)
            }
        }
    }
}
