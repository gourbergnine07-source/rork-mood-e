//
//  TVShowDetailViewModel.swift
//  MoodE
//

import Foundation
import Observation

/// Loads the full TMDB detail (cast, seasons, trailer, providers) for a TV show.
@Observable
final class TVShowDetailViewModel {
    enum LoadState {
        case loading
        case loaded(TMDBTVShowDetail)
        case failed(String)
        /// TMDB no longer knows this show id (removed from the catalog).
        case unavailable
    }

    private(set) var state: LoadState = .loading

    /// Fetches the detail for the given show id.
    func load(showID: Int) async {
        state = .loading
        do {
            let detail = try await TMDBService.tvDetail(id: showID)
            state = .loaded(detail)
        } catch TMDBError.badResponse(let statusCode) where statusCode == 404 {
            state = .unavailable
        } catch {
            let message = (error as? TMDBError)?.errorDescription ?? L("error.generic")
            state = .failed(message)
        }
    }
}
