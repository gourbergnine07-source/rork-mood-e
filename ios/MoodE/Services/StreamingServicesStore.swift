//
//  StreamingServicesStore.swift
//  MoodE
//

import Foundation
import Observation

/// Streaming services the user is subscribed to, chosen in Settings.
/// Drives the "Available now" badge on movie posters: a movie whose
/// subscription providers (from TMDB/JustWatch) match one of these
/// services gets the badge. Stored on device only.
@Observable
final class StreamingServicesStore {
    static let shared = StreamingServicesStore()

    /// A subscription service the user can mark as active. Matching
    /// against TMDB providers uses known provider ids first, then a
    /// normalized name fragment (lowercased, spaces removed) so ad-tier
    /// and regional variants ("Netflix Standard with Ads", "Rai Play")
    /// still match.
    struct Service: Identifiable, Hashable {
        let id: String
        let name: String
        let providerIds: Set<Int>
        let matchFragment: String
    }

    static let allServices: [Service] = [
        Service(id: "netflix", name: "Netflix", providerIds: [8, 1796], matchFragment: "netflix"),
        Service(id: "prime", name: "Prime Video", providerIds: [9, 119, 2100], matchFragment: "primevideo"),
        Service(id: "disney", name: "Disney+", providerIds: [337], matchFragment: "disney"),
        Service(id: "appletv", name: "Apple TV+", providerIds: [350], matchFragment: "appletv"),
        Service(id: "paramount", name: "Paramount+", providerIds: [531], matchFragment: "paramount"),
        Service(id: "now", name: "NOW", providerIds: [39], matchFragment: "nowtv"),
        Service(id: "raiplay", name: "RaiPlay", providerIds: [], matchFragment: "raiplay"),
        Service(id: "infinity", name: "Mediaset Infinity", providerIds: [], matchFragment: "infinity"),
        Service(id: "timvision", name: "TIMVISION", providerIds: [], matchFragment: "timvision"),
        Service(id: "crunchyroll", name: "Crunchyroll", providerIds: [283], matchFragment: "crunchyroll"),
        Service(id: "mubi", name: "Mubi", providerIds: [11], matchFragment: "mubi"),
    ]

    private(set) var selectedIds: Set<String>

    /// When true, mood-flow results only include movies available on one
    /// of the selected services. Persisted; ignored while no service is
    /// selected (see `isFilterActive`).
    private(set) var filterEnabled: Bool

    private static let storageKey = "streaming.services"
    private static let filterKey = "streaming.filterEnabled"

    private init() {
        let stored = UserDefaults.standard.stringArray(forKey: Self.storageKey) ?? []
        selectedIds = Set(stored)
        filterEnabled = UserDefaults.standard.bool(forKey: Self.filterKey)
    }

    var hasSelection: Bool { !selectedIds.isEmpty }

    /// Filter is effective only with both the toggle on and ≥1 service.
    var isFilterActive: Bool { filterEnabled && hasSelection }

    func setFilterEnabled(_ enabled: Bool) {
        filterEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.filterKey)
    }

    func isSelected(_ service: Service) -> Bool {
        selectedIds.contains(service.id)
    }

    func toggle(_ service: Service) {
        if selectedIds.contains(service.id) {
            selectedIds.remove(service.id)
        } else {
            selectedIds.insert(service.id)
        }
        persist()
    }

    /// Marks every service as subscribed (quick link in the filter panel).
    func selectAll() {
        selectedIds = Set(Self.allServices.map(\.id))
        persist()
    }

    /// Clears the whole selection so the user can start over.
    func deselectAll() {
        selectedIds = []
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(Array(selectedIds).sorted(), forKey: Self.storageKey)
    }

    /// True when at least one provider belongs to a selected service.
    func matchesAny(of providers: [TMDBWatchProvider]) -> Bool {
        guard hasSelection, !providers.isEmpty else { return false }
        let selected = Self.allServices.filter { selectedIds.contains($0.id) }
        return providers.contains { provider in
            let normalized = provider.providerName.lowercased().replacingOccurrences(of: " ", with: "")
            return selected.contains { service in
                service.providerIds.contains(provider.providerId) || normalized.contains(service.matchFragment)
            }
        }
    }
}
