//
//  ProfileStore.swift
//  MoodE
//

import Foundation
import Observation
import UIKit

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
    /// User's own profile photo (JPEG). Takes precedence over the emoji
    /// avatar in the UI; stored only on this device.
    private(set) var photoData: Data?

    private static let nameKey = "profile.displayName"
    private static let avatarKey = "profile.avatar"
    private static let photoFilename = "profile_photo.jpg"

    private static var photoURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(photoFilename)
    }

    private init() {
        customName = UserDefaults.standard.string(forKey: Self.nameKey) ?? ""
        let stored = UserDefaults.standard.string(forKey: Self.avatarKey)
        avatar = stored ?? Self.avatarChoices[0]
        photoData = try? Data(contentsOf: Self.photoURL)
    }

    /// Saves the custom display name (trimmed, capped at `maxNameLength`).
    /// An empty name falls back to the account name.
    func setName(_ name: String) {
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxNameLength))
        customName = trimmed
        UserDefaults.standard.set(trimmed, forKey: Self.nameKey)
    }

    /// Picking an emoji avatar also removes the custom photo, so the
    /// selection shown in the grid always matches what's displayed.
    func setAvatar(_ emoji: String) {
        guard Self.avatarChoices.contains(emoji) else { return }
        avatar = emoji
        UserDefaults.standard.set(emoji, forKey: Self.avatarKey)
        removePhoto()
    }

    /// Saves the user's own photo as the profile picture. The image is
    /// downscaled and re-encoded so it stays light on disk.
    func setPhoto(_ data: Data) {
        guard let processed = Self.processedPhoto(data) else { return }
        photoData = processed
        try? processed.write(to: Self.photoURL, options: .atomic)
    }

    func removePhoto() {
        guard photoData != nil || FileManager.default.fileExists(atPath: Self.photoURL.path) else { return }
        photoData = nil
        try? FileManager.default.removeItem(at: Self.photoURL)
    }

    /// Downscales to max 512pt on the longest side and re-encodes as JPEG.
    private static func processedPhoto(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let maxSide: CGFloat = 512
        let largest = max(image.size.width, image.size.height)
        guard largest > maxSide else { return image.jpegData(compressionQuality: 0.85) }

        let scale = maxSide / largest
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.85)
    }

    /// True when the profile differs from the defaults (no custom name,
    /// first avatar of the set) — drives the Reset button availability.
    var isCustomized: Bool {
        !customName.isEmpty || avatar != Self.avatarChoices[0] || photoData != nil
    }

    /// Restores the default profile: empty custom name (the account name
    /// takes over again) and the first avatar of the predefined set.
    func reset() {
        customName = ""
        avatar = Self.avatarChoices[0]
        UserDefaults.standard.removeObject(forKey: Self.nameKey)
        UserDefaults.standard.removeObject(forKey: Self.avatarKey)
        removePhoto()
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
