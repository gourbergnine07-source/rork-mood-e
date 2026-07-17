//
//  TrendingViewModel.swift
//  MoodE
//

import Foundation
import Observation

/// Loads TMDB trending movies for the Tendenze tab, backed by a
/// 6-hour local cache and silent background refreshes on app open.
@Observable
final class TrendingViewModel {
    enum State {
        case idle
        case loading
        case loaded([TMDBMovie])
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var isRefreshing = false
    var window: TrendingWindow = .week

    /// In-memory cache per window so switching the selector is instant.
    private var memoryCache: [TrendingWindow: [TMDBMovie]] = [:]

    private func cacheKey(for window: TrendingWindow) -> String {
        "trending.\(window.rawValue)"
    }

    /// Loads trending movies: serves the local cache when fresh (< 6h),
    /// otherwise shows cached data instantly and refreshes in background.
    func load(forceRefresh: Bool = false) async {
        let window = self.window

        if !forceRefresh {
            if let cached = memoryCache[window] {
                state = .loaded(cached)
                return
            }
            if let disk = TMDBCache.load([TMDBMovie].self, forKey: cacheKey(for: window)) {
                memoryCache[window] = disk.value
                state = .loaded(disk.value)
                if disk.isFresh { return }
                await refresh(window: window)
                return
            }
        }

        if memoryCache[window] == nil {
            state = .loading
        }
        await refresh(window: window)
    }

    /// Silent refresh triggered when the app returns to the foreground:
    /// hits the API only if the cached data is older than 6 hours.
    func refreshIfStale() async {
        let window = self.window
        if let disk = TMDBCache.load([TMDBMovie].self, forKey: cacheKey(for: window)), disk.isFresh {
            return
        }
        guard !isRefreshing else { return }
        await refresh(window: window)
    }

    private func refresh(window: TrendingWindow) async {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let movies = try await TMDBService.trendingMovies(window: window)
            memoryCache[window] = movies
            TMDBCache.save(movies, forKey: cacheKey(for: window))
            guard self.window == window else { return }
            state = .loaded(movies)
        } catch {
            guard self.window == window else { return }
            if let cached = memoryCache[window] {
                state = .loaded(cached)
            } else {
                let message = (error as? TMDBError)?.errorDescription
                    ?? "Qualcosa è andato storto. Controlla la connessione e riprova."
                state = .failed(message)
            }
        }
    }
}
