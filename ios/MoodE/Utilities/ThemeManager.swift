//
//  ThemeManager.swift
//  MoodE
//

import SwiftUI

/// Holds the user's chosen accent palette and persists it.
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

    private static let accentKey = "theme.accent"

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.accentKey)
        accent = AccentPalette(rawValue: stored ?? "") ?? .azzurro
    }
}
