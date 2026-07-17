//
//  MovieResultsViewModel.swift
//  MoodE
//

import Foundation
import Observation

/// Loads mood-based movie recommendations from TMDB for the results screen,
/// with support for fresh batches via discover pagination.
@Observable
final class MovieResultsViewModel {
    enum LoadState {
        case loading
        case loaded([TMDBMovie])
        case failed(String)
    }

    private(set) var state: LoadState = .loading
    private(set) var isRefreshing: Bool = false
    /// Incremented on every successful batch, used to scroll back to top.
    private(set) var batchId: Int = 0

    private var currentPage: Int = 1
    private var totalPages: Int = 1

    /// Maximum number of movies shown per batch.
    private let batchSize = 15

    /// Fetches the first batch of recommendations for the given flow selection.
    func load(selection: MoodSelection) async {
        state = .loading
        currentPage = 1
        await fetch(selection: selection, page: 1)
    }

    /// Fetches a fresh batch (next discover page) keeping the same filters.
    /// Wraps back to page 1 after the last available page.
    func loadNewBatch(selection: MoodSelection) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        let nextPage = currentPage >= totalPages ? 1 : currentPage + 1
        await fetch(selection: selection, page: nextPage)
        isRefreshing = false
    }

    private func fetch(selection: MoodSelection, page: Int) async {
        do {
            let response = try await TMDBService.discoverMovies(for: selection, page: page)
            currentPage = response.page
            totalPages = max(response.totalPages, 1)
            state = .loaded(Array(response.results.prefix(batchSize)))
            batchId += 1
        } catch {
            let message = (error as? TMDBError)?.errorDescription
                ?? "Qualcosa è andato storto. Controlla la connessione e riprova."
            state = .failed(message)
        }
    }
}
