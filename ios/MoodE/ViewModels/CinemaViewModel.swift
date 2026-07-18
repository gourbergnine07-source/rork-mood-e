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
    let latitude: Double?
    let longitude: Double?

    /// Opens Apple Maps with driving directions to this cinema.
    func openDirectionsInMaps() {
        guard let latitude, let longitude else { return }
        let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    /// Distance formatted with the user's locale (e.g. "2,3 km" vs "2.3 km").
    var formattedDistance: String? {
        guard let distanceMeters else { return nil }
        if distanceMeters < 1000 {
            return "\(Int(distanceMeters)) m"
        }
        let km = distanceMeters / 1000
        return String(format: "%.1f km", locale: LocalizationManager.shared.locale, km)
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
    private(set) var isRefreshing = false

    /// Localized display name of the region (e.g. "Italia" / "Italy").
    var regionName: String {
        LocalizationManager.shared.locale.localizedString(forRegionCode: regionCode) ?? regionCode
    }

    var hasLoaded: Bool {
        if case .loaded = state { return true }
        return false
    }

    private func cacheKey(for region: String) -> String {
        "nowPlaying.\(region)"
    }

    /// Loads now-playing movies: serves the local cache when fresh (< 6h),
    /// otherwise shows cached data instantly and refreshes in background.
    @MainActor
    func load(region: String, forceRefresh: Bool = false) async {
        regionCode = region

        if !forceRefresh, let disk = TMDBCache.load([TMDBMovie].self, forKey: cacheKey(for: region)) {
            state = .loaded(disk.value)
            if disk.isFresh { return }
        } else if !hasLoaded {
            state = .loading
        }

        await refresh(region: region)
    }

    /// Silent refresh triggered when the app returns to the foreground:
    /// hits the API only if the cached data is older than 6 hours.
    func refreshIfStale() async {
        guard hasLoaded else { return }
        if let disk = TMDBCache.load([TMDBMovie].self, forKey: cacheKey(for: regionCode)), disk.isFresh {
            return
        }
        guard !isRefreshing else { return }
        await refresh(region: regionCode)
    }

    private func refresh(region: String) async {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let movies = try await TMDBService.nowPlayingMovies(region: region)
            TMDBCache.save(movies, forKey: cacheKey(for: region))
            state = .loaded(movies)
        } catch {
            if case .loaded = state {
                // Keep showing cached data when a background refresh fails.
            } else {
                state = .failed(L("error.cinema"))
            }
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
                        distanceMeters: distance,
                        latitude: itemLocation?.coordinate.latitude,
                        longitude: itemLocation?.coordinate.longitude
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
