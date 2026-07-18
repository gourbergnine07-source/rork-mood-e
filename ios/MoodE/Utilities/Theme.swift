//
//  Theme.swift
//  MoodE
//

import SwiftUI
import UIKit

/// Emotional color palette for Mood-E.
/// Every token is a dynamic iOS system color: it resolves automatically
/// against the system appearance (light or dark) via `UITraitCollection`.
enum Theme {
    /// Builds an adaptive color that follows the system light/dark appearance.
    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    /// Returns `base` with hue/saturation/brightness shifted (hue wraps around).
    /// Used to derive harmonious per-tab accents from the user's palette.
    private static func shifted(_ base: UIColor, hue dH: CGFloat, saturation dS: CGFloat = 0, brightness dB: CGFloat = 0) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        base.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        var hue = (h + dH).truncatingRemainder(dividingBy: 1)
        if hue < 0 { hue += 1 }
        return UIColor(
            hue: hue,
            saturation: min(max(s + dS, 0), 1),
            brightness: min(max(b + dB, 0), 1),
            alpha: a
        )
    }

    /// Adaptive accent derived from the selected palette's primary,
    /// shifted in hue/brightness to stay in harmony with the palette.
    private static func paletteAccent(hue dH: CGFloat, saturation dS: CGFloat = 0, brightness dB: CGFloat = 0) -> Color {
        let palette = ThemeManager.shared.accent
        return adaptive(
            light: shifted(palette.primaryLight, hue: dH, saturation: dS, brightness: dB),
            dark: shifted(palette.primaryDark, hue: dH, saturation: dS, brightness: dB)
        )
    }

    // MARK: - Neutral surfaces (adaptive, follow the user's chosen palette)

    /// App background, tinted by the selected accent palette.
    static var background: Color {
        let palette = ThemeManager.shared.accent
        return adaptive(light: palette.backgroundLight, dark: palette.backgroundDark)
    }

    /// Cards and secondary surfaces, tinted by the selected accent palette.
    static var surface: Color {
        let palette = ThemeManager.shared.accent
        return adaptive(light: palette.surfaceLight, dark: palette.surfaceDark)
    }

    /// Frosted card background used behind content cards and chips
    /// (replaces the old hardcoded `.white.opacity(...)` fills).
    static let card = adaptive(
        light: UIColor(white: 1, alpha: 0.72),
        dark: UIColor(red: 0.145, green: 0.184, blue: 0.247, alpha: 0.92)
    )

    /// Slightly stronger card background for hero/selection cards.
    static let cardStrong = adaptive(
        light: UIColor(white: 1, alpha: 0.85),
        dark: UIColor(red: 0.165, green: 0.208, blue: 0.278, alpha: 0.96)
    )

    /// Moving highlight color for skeleton shimmer.
    static let shimmerHighlight = adaptive(
        light: UIColor(white: 1, alpha: 0.6),
        dark: UIColor(white: 1, alpha: 0.16)
    )

    // MARK: - Text (adaptive, warm-tinted like the system label colors)

    /// Primary text: deep warm brown in light, warm cream in dark.
    static let ink = adaptive(
        light: UIColor(red: 0.239, green: 0.169, blue: 0.137, alpha: 1),
        dark: UIColor(red: 0.949, green: 0.918, blue: 0.890, alpha: 1)
    )

    /// Secondary text: softer brown in light, muted warm gray in dark.
    static let inkSoft = adaptive(
        light: UIColor(red: 0.478, green: 0.388, blue: 0.337, alpha: 1),
        dark: UIColor(red: 0.729, green: 0.694, blue: 0.659, alpha: 1)
    )

    /// Text/icon color for content placed on top of `ink`-colored fills
    /// (white on brown in light, deep navy on cream in dark).
    static let inkInverse = adaptive(
        light: UIColor.white,
        dark: UIColor(red: 0.071, green: 0.098, blue: 0.145, alpha: 1)
    )

    // MARK: - Accents (brightened in dark for contrast on dark surfaces)

    /// Primary accent, chosen by the user in Impostazioni > Aspetto.
    static var primary: Color {
        let palette = ThemeManager.shared.accent
        return adaptive(light: palette.primaryLight, dark: palette.primaryDark)
    }

    /// Soft amber secondary accent.
    static let amber = adaptive(
        light: UIColor(red: 0.957, green: 0.694, blue: 0.353, alpha: 1),
        dark: UIColor(red: 0.980, green: 0.749, blue: 0.439, alpha: 1)
    )

    /// Muted rose accent for emotional touches.
    static let rose = adaptive(
        light: UIColor(red: 0.898, green: 0.573, blue: 0.522, alpha: 1),
        dark: UIColor(red: 0.949, green: 0.639, blue: 0.588, alpha: 1)
    )

    /// Confident green for the "already seen" state.
    static let seenGreen = adaptive(
        light: UIColor(red: 0.28, green: 0.6, blue: 0.42, alpha: 1),
        dark: UIColor(red: 0.369, green: 0.729, blue: 0.529, alpha: 1)
    )

    // MARK: - Tab accent colors (adaptive, all derived from the user's palette)

    /// Home tab: follows the user's primary accent.
    static var tabHome: Color { primary }

    /// Tendenze tab: warm sibling of the primary accent.
    static var tabTrending: Color {
        paletteAccent(hue: 0.055, brightness: 0.03)
    }

    /// Al Cinema tab: cool sibling of the primary accent.
    static var tabCinema: Color {
        paletteAccent(hue: -0.065)
    }

    /// La mia lista tab: softer, further-shifted sibling of the primary accent.
    static var tabList: Color {
        paletteAccent(hue: 0.11, brightness: 0.02)
    }

    /// Impostazioni tab: calm, opposite-shifted sibling of the primary accent.
    static var tabSettings: Color {
        paletteAccent(hue: -0.12)
    }
}
