//
//  SpectatorProfile.swift
//  MoodE
//

import SwiftUI

/// Cinematic personality assigned by the "Che spettatore sei?" quiz.
/// Stored locally and used as a light extra ranking factor in the
/// recommendations (it refines, never replaces, the mood flow).
enum SpectatorProfile: String, CaseIterable, Identifiable {
    case sognatoreNostalgico
    case avventurieroCurioso
    case romanticoIncallito
    case esploratoreDiGeneri
    case cercatoreDiBrividi
    case animaMalinconica

    var id: String { rawValue }

    var title: String { L("quiz.profile.\(rawValue).title") }
    var detail: String { L("quiz.profile.\(rawValue).desc") }

    var emoji: String {
        switch self {
        case .sognatoreNostalgico: return "🌠"
        case .avventurieroCurioso: return "🧗"
        case .romanticoIncallito: return "💞"
        case .esploratoreDiGeneri: return "🧭"
        case .cercatoreDiBrividi: return "🎢"
        case .animaMalinconica: return "🌧️"
        }
    }

    /// SF Symbol fallback when the emoji font is unavailable.
    var icon: String {
        switch self {
        case .sognatoreNostalgico: return "sparkles"
        case .avventurieroCurioso: return "figure.climbing"
        case .romanticoIncallito: return "heart.circle.fill"
        case .esploratoreDiGeneri: return "safari.fill"
        case .cercatoreDiBrividi: return "bolt.heart.fill"
        case .animaMalinconica: return "cloud.drizzle.fill"
        }
    }

    /// Signature gradient for the result screen and the share card.
    var gradient: [Color] {
        switch self {
        case .sognatoreNostalgico:
            return [Color(red: 0.29, green: 0.23, blue: 0.55), Color(red: 0.72, green: 0.45, blue: 0.66)]
        case .avventurieroCurioso:
            return [Color(red: 0.85, green: 0.42, blue: 0.12), Color(red: 0.42, green: 0.24, blue: 0.10)]
        case .romanticoIncallito:
            return [Color(red: 0.86, green: 0.28, blue: 0.44), Color(red: 0.47, green: 0.10, blue: 0.28)]
        case .esploratoreDiGeneri:
            return [Color(red: 0.11, green: 0.47, blue: 0.45), Color(red: 0.06, green: 0.24, blue: 0.32)]
        case .cercatoreDiBrividi:
            return [Color(red: 0.36, green: 0.16, blue: 0.52), Color(red: 0.10, green: 0.08, blue: 0.20)]
        case .animaMalinconica:
            return [Color(red: 0.30, green: 0.40, blue: 0.58), Color(red: 0.13, green: 0.17, blue: 0.28)]
        }
    }

    /// TMDB genres gently boosted in the results ranking.
    var boostGenres: [Int] {
        switch self {
        case .sognatoreNostalgico: return [14, 16, 10751]
        case .avventurieroCurioso: return [12, 28, 878]
        case .romanticoIncallito: return [10749, 35]
        case .esploratoreDiGeneri: return [99, 36, 10402]
        case .cercatoreDiBrividi: return [27, 53, 9648]
        case .animaMalinconica: return [18, 10402]
        }
    }
}
