//
//  TrendingViewModel.swift
//  MoodE
//

import Foundation
import Observation

/// Loads and caches TMDB trending movies for the Tendenze tab.
@Observable
final class TrendingViewModel {
    enum State {
        case idle
        case loading
        case loaded([TMDBMovie])
        case failed(String)
    }

    private(set) var state: State = .idle
    var window: TrendingWindow = .week

    /// Cache per window so switching the selector is instant after first load.
    private var cache: [TrendingWindow: [TMDBMovie]] = [:]

    /// Loads trending movies for the current window, using the cache when available.
    func load(forceRefresh: Bool = false) async {
        let window = self.window

        if !forceRefresh, let cached = cache[window] {
            state = .loaded(cached)
            return
        }

        if cache[window] == nil {
            state = .loading
        }

        do {
            let movies = try await TMDBService.trendingMovies(window: window)
            cache[window] = movies
            guard self.window == window else { return }
            state = .loaded(movies)
        } catch {
            guard self.window == window else { return }
            if let cached = cache[window] {
                state = .loaded(cached)
            } else {
                state = .failed(error.localizedDescription)
            }
        }
    }
}
