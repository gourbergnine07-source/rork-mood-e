//
//  MovieDetailViewModel.swift
//  MoodE
//

import Foundation
import Observation

/// Loads the full TMDB detail (cast, runtime, trailer) for a movie.
@Observable
final class MovieDetailViewModel {
    enum LoadState {
        case loading
        case loaded(TMDBMovieDetail)
        case failed(String)
    }

    private(set) var state: LoadState = .loading

    /// Fetches the detail for the given movie id.
    func load(movieID: Int) async {
        state = .loading
        do {
            let detail = try await TMDBService.movieDetail(id: movieID)
            state = .loaded(detail)
        } catch {
            let message = (error as? TMDBError)?.errorDescription
                ?? "Qualcosa è andato storto. Controlla la connessione e riprova."
            state = .failed(message)
        }
    }
}
