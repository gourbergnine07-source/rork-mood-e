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

    // MARK: - Neutral surfaces (adaptive)

    /// App background: soft azure in light, deep night blue in dark.
    static let background = adaptive(
        light: UIColor(red: 0.859, green: 0.929, blue: 0.984, alpha: 1),
        dark: UIColor(red: 0.071, green: 0.098, blue: 0.145, alpha: 1)
    )

    /// Cards and secondary surfaces: deeper azure in light, elevated navy in dark.
    static let surface = adaptive(
        light: UIColor(red: 0.796, green: 0.886, blue: 0.961, alpha: 1),
        dark: UIColor(red: 0.118, green: 0.153, blue: 0.212, alpha: 1)
    )

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

    /// Primary intense azure accent.
    static let primary = adaptive(
        light: UIColor(red: 0.090, green: 0.443, blue: 0.851, alpha: 1),
        dark: UIColor(red: 0.310, green: 0.612, blue: 0.969, alpha: 1)
    )

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

    // MARK: - Tab accent colors (adaptive)

    /// Home tab: intense azure.
    static let tabHome = primary

    /// Tendenze tab: fiery amber-orange.
    static let tabTrending = adaptive(
        light: UIColor(red: 0.94, green: 0.52, blue: 0.16, alpha: 1),
        dark: UIColor(red: 0.988, green: 0.612, blue: 0.278, alpha: 1)
    )

    /// Al Cinema tab: deep indigo like a cinema at night.
    static let tabCinema = adaptive(
        light: UIColor(red: 0.36, green: 0.44, blue: 0.85, alpha: 1),
        dark: UIColor(red: 0.541, green: 0.612, blue: 0.949, alpha: 1)
    )

    /// La mia lista tab: soft rose.
    static let tabList = adaptive(
        light: UIColor(red: 0.86, green: 0.38, blue: 0.55, alpha: 1),
        dark: UIColor(red: 0.929, green: 0.494, blue: 0.651, alpha: 1)
    )

    /// Impostazioni tab: calm deep teal.
    static let tabSettings = adaptive(
        light: UIColor(red: 0.18, green: 0.52, blue: 0.53, alpha: 1),
        dark: UIColor(red: 0.302, green: 0.671, blue: 0.682, alpha: 1)
    )
}
