//
//  MovieResultsViewModel.swift
//  MoodE
//

import Foundation
import Observation

/// Loads mood-based movie recommendations from TMDB for the results screen.
@Observable
final class MovieResultsViewModel {
    enum LoadState {
        case loading
        case loaded([TMDBMovie])
        case failed(String)
    }

    private(set) var state: LoadState = .loading

    /// Fetches recommendations for the given flow selection.
    func load(selection: MoodSelection) async {
        state = .loading
        do {
            let movies = try await TMDBService.discoverMovies(for: selection)
            state = .loaded(movies)
        } catch {
            let message = (error as? TMDBError)?.errorDescription
                ?? "Qualcosa è andato storto. Controlla la connessione e riprova."
            state = .failed(message)
        }
    }
}
