//
//  CinemaViewModel.swift
//  MoodE
//

import Foundation
import Observation

/// Loads movies currently playing in theatres for a given region.
@Observable
final class CinemaViewModel {
    enum State {
        case idle
        case loading
        case failed(String)
        case loaded([TMDBMovie])
    }

    private(set) var state: State = .idle
    private(set) var regionCode: String = "IT"

    /// Italian display name of the region (e.g. "Italia").
    var regionName: String {
        Locale(identifier: "it_IT").localizedString(forRegionCode: regionCode) ?? regionCode
    }

    var hasLoaded: Bool {
        if case .loaded = state { return true }
        return false
    }

    @MainActor
    func load(region: String) async {
        regionCode = region
        state = .loading
        do {
            let movies = try await TMDBService.nowPlayingMovies(region: region)
            state = .loaded(movies)
        } catch {
            state = .failed("Non riusciamo a caricare i film in sala. Controlla la connessione e riprova.")
        }
    }
}
