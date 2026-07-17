//
//  MovieResultsViewModel.swift
//  MoodE
//

import Foundation
import Observation

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

    /// Fetches the first batch of recommendations for the given flow selection.
    func load(selection: MoodSelection, excluding excludedIds: Set<Int> = []) async {
        state = .loading
        currentPage = 1
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

            state = .loaded(Array(collected.prefix(batchSize)))
            batchId += 1
        } catch {
            let message = (error as? TMDBError)?.errorDescription
                ?? "Qualcosa è andato storto. Controlla la connessione e riprova."
            state = .failed(message)
        }
    }
}
