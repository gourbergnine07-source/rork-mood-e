//
//  TVFollowStore.swift
//  MoodE
//

import Foundation
import Observation

/// TV series the user follows for new-episode alerts ("Emissioni
/// televisive", Premium). Stored only on device; every change re-syncs
/// the episode notifications.
@Observable
final class TVFollowStore {
    static let shared = TVFollowStore()

    /// Minimal snapshot of a followed show, enough to schedule and route
    /// its notifications without another network call.
    nonisolated struct FollowedShow: Codable, Identifiable, Hashable {
        let id: Int
        let name: String
        let posterPath: String?
    }

    private static let storageKey = "tv.followed"

    private(set) var follows: [FollowedShow]

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let stored = try? JSONDecoder().decode([FollowedShow].self, from: data) {
            follows = stored
        } else {
            follows = []
        }
    }

    func isFollowing(_ id: Int) -> Bool {
        follows.contains { $0.id == id }
    }

    /// Follows or unfollows a show and re-syncs the episode reminders.
    func toggle(id: Int, name: String, posterPath: String?) {
        if isFollowing(id) {
            follows.removeAll { $0.id == id }
        } else {
            follows.append(FollowedShow(id: id, name: name, posterPath: posterPath))
        }
        persist()
        Task { await TVEpisodeNotifier.sync() }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(follows) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
