//
//  LocationService.swift
//  MoodE
//

import Foundation
import CoreLocation
import Observation

/// Handles location permission and resolves the user's country code,
/// used to show now-playing movies for the right region.
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
        authorizationStatus = manager.authorizationStatus
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    /// Triggers the system when-in-use permission prompt.
    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
        }
    }

    /// Resolves the ISO country code (e.g. "IT") from the current position.
    /// Returns nil if the position or the reverse geocoding fails.
    func resolveCountryCode() async -> String? {
        guard isAuthorized else { return nil }

        do {
            var found: CLLocation?
            var attempts = 0
            for try await update in CLLocationUpdate.liveUpdates() {
                attempts += 1
                if let location = update.location {
                    found = location
                    break
                }
                if attempts >= 8 { break }
            }

            guard let location = found else { return nil }
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
            return placemarks.first?.isoCountryCode
        } catch {
            print("LocationService: failed to resolve country code: \(error.localizedDescription)")
            return nil
        }
    }
}
