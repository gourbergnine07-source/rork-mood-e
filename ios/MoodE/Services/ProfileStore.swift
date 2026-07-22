//
//  ProfileStore.swift
//  MoodE
//

import Foundation
import Observation

/// Local user profile: the display name shown to friends in challenges and
/// an avatar picked from a predefined, movie-themed set. Stored on device
/// only — no personal data leaves the phone beyond the name already shared
/// with linked friends.
@Observable
final class ProfileStore {
    static let shared = ProfileStore()

    /// Predefined avatar choices (movie-night themed).
    static let avatarChoices: [String] = [
        "🎬", "🍿", "🎥", "🎞️", "🎭", "⭐️",
        "🦸", "🦹", "🧙", "🧛", "🤖", "👻",
        "👽", "🕵️", "🐉", "🚀", "🌙", "🔥",
    ]

    static let maxNameLength = 20

    private(set) var customName: String
    private(set) var avatar: String

    private static let nameKey = "profile.displayName"
    private static let avatarKey = "profile.avatar"

    private init() {
        customName = UserDefaults.standard.string(forKey: Self.nameKey) ?? ""
        let stored = UserDefaults.standard.string(forKey: Self.avatarKey)
        avatar = stored ?? Self.avatarChoices[0]
    }

    /// Saves the custom display name (trimmed, capped at `maxNameLength`).
    /// An empty name falls back to the account name.
    func setName(_ name: String) {
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxNameLength))
        customName = trimmed
        UserDefaults.standard.set(trimmed, forKey: Self.nameKey)
    }

    func setAvatar(_ emoji: String) {
        guard Self.avatarChoices.contains(emoji) else { return }
        avatar = emoji
        UserDefaults.standard.set(emoji, forKey: Self.avatarKey)
    }

    /// Name shown to friends: the custom name first, then the account
    /// name, then the email prefix, then the generic fallback.
    func resolvedName(auth: AuthManager) -> String {
        if !customName.isEmpty { return customName }
        if let name = auth.user?.name, !name.isEmpty { return name }
        if let email = auth.user?.email, let prefix = email.split(separator: "@").first {
            return String(prefix)
        }
        return "Cinefilo"
    }
}
