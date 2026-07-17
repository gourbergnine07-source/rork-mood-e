//
//  Theme.swift
//  MoodE
//

import SwiftUI

/// Emotional color palette for Mood-E: soft azure background with warm accents.
enum Theme {
    /// Soft azure app background.
    static let background = Color(red: 0.859, green: 0.929, blue: 0.984)
    /// Slightly deeper azure tone for cards and surfaces.
    static let surface = Color(red: 0.796, green: 0.886, blue: 0.961)
    /// Primary terracotta/coral accent.
    static let primary = Color(red: 0.886, green: 0.439, blue: 0.294)
    /// Soft amber secondary accent.
    static let amber = Color(red: 0.957, green: 0.694, blue: 0.353)
    /// Muted rose accent for emotional touches.
    static let rose = Color(red: 0.898, green: 0.573, blue: 0.522)
    /// Deep warm brown for primary text.
    static let ink = Color(red: 0.239, green: 0.169, blue: 0.137)
    /// Softer brown for secondary text.
    static let inkSoft = Color(red: 0.478, green: 0.388, blue: 0.337)
}
