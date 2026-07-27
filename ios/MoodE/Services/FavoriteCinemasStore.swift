//
//  FavoriteCinemasStore.swift
//  MoodE
//
//  Saved favorite cinemas ("I miei cinema") with links to their REAL
//  programme. TMDB has no per-venue showtime data, so the programme
//  always opens on the cinema's official website (from Apple Maps) or,
//  when no site is available, on a prefilled web search for the venue.
//

import Foundation
import CoreLocation
import MapKit
import Observation

/// A cinema saved by the user. Stores only static venue data;
/// distance is recomputed from the current position at display time.
struct FavoriteCinema: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let address: String?
    let latitude: Double?
    let longitude: Double?
    let website: URL?
    let city: String?

    init(from cinema: NearbyCinema) {
        id = cinema.id
        name = cinema.name
        address = cinema.address
        latitude = cinema.latitude
        longitude = cinema.longitude
        website = cinema.website
        city = cinema.city
    }

    /// Live distance from the user's current position, locale-formatted.
    func formattedDistance(from location: CLLocation?) -> String? {
        guard let location, let latitude, let longitude else { return nil }
        let meters = CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: location)
        return NearbyCinema.formatDistance(meters)
    }

    /// Real programme link: the official website when Apple Maps provides
    /// one, otherwise a prefilled web search "name + city + showtimes".
    var showtimesURL: URL? {
        if let website { return website }
        var terms = [name]
        if let city, !city.isEmpty { terms.append(city) }
        terms.append(L("cinema.fav.searchTerms"))
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: terms.joined(separator: " "))]
        return components?.url
    }

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
}

/// Persists the user's favorite cinemas on-device (UserDefaults).
@Observable
final class FavoriteCinemasStore {
    static let shared = FavoriteCinemasStore()
    private static let storageKey = "cinema.favorites"

    private(set) var cinemas: [FavoriteCinema] = []

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode([FavoriteCinema].self, from: data) {
            cinemas = saved
        }
    }

    func isFavorite(_ id: String) -> Bool {
        cinemas.contains { $0.id == id }
    }

    /// Adds the cinema to favorites, or removes it if already saved.
    func toggle(_ cinema: NearbyCinema) {
        if isFavorite(cinema.id) {
            remove(id: cinema.id)
        } else {
            cinemas.append(FavoriteCinema(from: cinema))
            save()
            AnalyticsService.shared.log("cinema_favorite_add")
        }
    }

    func remove(id: String) {
        cinemas.removeAll { $0.id == id }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(cinemas) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
