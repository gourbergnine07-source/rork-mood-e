//
//  ThemeManager.swift
//  MoodE
//

import SwiftUI

/// User-selectable appearance mode: follow the system or force light/dark.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    /// Localized label shown in the settings picker.
    var displayName: String { L("appearance.\(rawValue)") }

    /// SF Symbol shown next to the label.
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    /// Value passed to `.preferredColorScheme`; nil follows the system.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Holds the user's chosen accent palette and appearance mode, persisting both.
/// Views that read `Theme` tokens during body evaluation automatically
/// track this observable, so a palette change re-renders the whole UI.
@Observable
final class ThemeManager {
    static let shared = ThemeManager()

    var accent: AccentPalette {
        didSet {
            UserDefaults.standard.set(accent.rawValue, forKey: Self.accentKey)
        }
    }

    /// Forced light/dark appearance, or `.system` to follow iOS.
    var appearance: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: Self.appearanceKey)
        }
    }

    private static let accentKey = "theme.accent"
    private static let appearanceKey = "theme.appearance"

    private init() {
        let storedAccent = UserDefaults.standard.string(forKey: Self.accentKey)
        accent = AccentPalette(rawValue: storedAccent ?? "") ?? .azzurro
        let storedAppearance = UserDefaults.standard.string(forKey: Self.appearanceKey)
        appearance = AppearanceMode(rawValue: storedAppearance ?? "") ?? .system
    }
}
