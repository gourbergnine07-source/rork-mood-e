//
//  CinemaViewModel.swift
//  MoodE
//

import Foundation
import Observation
import MapKit
import CoreLocation

/// A movie theatre found near the user's position via Apple Maps search.
struct NearbyCinema: Identifiable, Hashable {
    let id: String
    let name: String
    let address: String?
    let distanceMeters: Double?

    /// Distance formatted in Italian (e.g. "850 m" or "2,3 km").
    var formattedDistance: String? {
        guard let distanceMeters else { return nil }
        if distanceMeters < 1000 {
            return "\(Int(distanceMeters)) m"
        }
        let km = distanceMeters / 1000
        return String(format: "%.1f km", locale: Locale(identifier: "it_IT"), km)
    }
}

/// Loads movies currently playing in theatres for a given region.
@Observable
final class CinemaViewModel {
    enum State {
        case idle
        case loading
        case failed(String)
        case loaded([TMDBMovie])
    }

    enum CinemasState {
        case idle
        case loading
        case unavailable
        case loaded([NearbyCinema])
    }

    private(set) var state: State = .idle
    private(set) var cinemasState: CinemasState = .idle
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

    /// Searches movie theatres within ~15 km of the user's position via Apple Maps.
    @MainActor
    func loadNearbyCinemas(around location: CLLocation) async {
        cinemasState = .loading

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "cinema"
        request.resultTypes = .pointOfInterest
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.movieTheater])
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: 15000,
            longitudinalMeters: 15000
        )

        do {
            let response = try await MKLocalSearch(request: request).start()
            let cinemas = response.mapItems
                .compactMap { item -> NearbyCinema? in
                    guard let name = item.name else { return nil }
                    let itemLocation = item.placemark.location
                    let distance = itemLocation.map { location.distance(from: $0) }
                    let street = [item.placemark.thoroughfare, item.placemark.subThoroughfare]
                        .compactMap { $0 }
                        .joined(separator: " ")
                    let address = [street.isEmpty ? nil : street, item.placemark.locality]
                        .compactMap { $0 }
                        .joined(separator: ", ")
                    return NearbyCinema(
                        id: "\(name)|\(itemLocation?.coordinate.latitude ?? 0)|\(itemLocation?.coordinate.longitude ?? 0)",
                        name: name,
                        address: address.isEmpty ? nil : address,
                        distanceMeters: distance
                    )
                }
                .sorted { ($0.distanceMeters ?? .greatestFiniteMagnitude) < ($1.distanceMeters ?? .greatestFiniteMagnitude) }

            var seen = Set<String>()
            let unique = cinemas.filter { seen.insert($0.id).inserted }

            cinemasState = unique.isEmpty ? .unavailable : .loaded(Array(unique.prefix(6)))
        } catch {
            print("CinemaViewModel: nearby cinema search failed: \(error.localizedDescription)")
            cinemasState = .unavailable
        }
    }
}
