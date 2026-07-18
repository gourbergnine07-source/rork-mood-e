//
//  AccentPalette.swift
//  MoodE
//

import SwiftUI
import UIKit

/// Selectable color palettes that let the user personalize the app.
/// Each palette defines the primary accent plus tinted backgrounds,
/// with dedicated variants for light and dark appearance.
enum AccentPalette: String, CaseIterable, Identifiable {
    case azzurro
    case tramonto
    case rosa
    case smeraldo
    case viola
    case grafite

    var id: String { rawValue }

    /// Italian display name shown in the settings picker.
    var displayName: String {
        switch self {
        case .azzurro: return "Azzurro"
        case .tramonto: return "Tramonto"
        case .rosa: return "Rosa"
        case .smeraldo: return "Smeraldo"
        case .viola: return "Viola"
        case .grafite: return "Grafite"
        }
    }

    // MARK: - Primary accent

    var primaryLight: UIColor {
        switch self {
        case .azzurro: return UIColor(red: 0.090, green: 0.443, blue: 0.851, alpha: 1)
        case .tramonto: return UIColor(red: 0.851, green: 0.404, blue: 0.110, alpha: 1)
        case .rosa: return UIColor(red: 0.831, green: 0.290, blue: 0.510, alpha: 1)
        case .smeraldo: return UIColor(red: 0.110, green: 0.541, blue: 0.412, alpha: 1)
        case .viola: return UIColor(red: 0.463, green: 0.310, blue: 0.800, alpha: 1)
        case .grafite: return UIColor(red: 0.271, green: 0.322, blue: 0.400, alpha: 1)
        }
    }

    var primaryDark: UIColor {
        switch self {
        case .azzurro: return UIColor(red: 0.310, green: 0.612, blue: 0.969, alpha: 1)
        case .tramonto: return UIColor(red: 0.976, green: 0.588, blue: 0.290, alpha: 1)
        case .rosa: return UIColor(red: 0.937, green: 0.490, blue: 0.659, alpha: 1)
        case .smeraldo: return UIColor(red: 0.298, green: 0.729, blue: 0.569, alpha: 1)
        case .viola: return UIColor(red: 0.659, green: 0.541, blue: 0.957, alpha: 1)
        case .grafite: return UIColor(red: 0.651, green: 0.710, blue: 0.800, alpha: 1)
        }
    }

    // MARK: - App background

    var backgroundLight: UIColor {
        switch self {
        case .azzurro: return UIColor(red: 0.859, green: 0.929, blue: 0.984, alpha: 1)
        case .tramonto: return UIColor(red: 0.988, green: 0.925, blue: 0.859, alpha: 1)
        case .rosa: return UIColor(red: 0.984, green: 0.910, blue: 0.937, alpha: 1)
        case .smeraldo: return UIColor(red: 0.878, green: 0.949, blue: 0.918, alpha: 1)
        case .viola: return UIColor(red: 0.925, green: 0.906, blue: 0.976, alpha: 1)
        case .grafite: return UIColor(red: 0.918, green: 0.929, blue: 0.945, alpha: 1)
        }
    }

    var backgroundDark: UIColor {
        switch self {
        case .azzurro: return UIColor(red: 0.071, green: 0.098, blue: 0.145, alpha: 1)
        case .tramonto: return UIColor(red: 0.129, green: 0.094, blue: 0.067, alpha: 1)
        case .rosa: return UIColor(red: 0.133, green: 0.082, blue: 0.106, alpha: 1)
        case .smeraldo: return UIColor(red: 0.059, green: 0.114, blue: 0.098, alpha: 1)
        case .viola: return UIColor(red: 0.098, green: 0.082, blue: 0.145, alpha: 1)
        case .grafite: return UIColor(red: 0.086, green: 0.094, blue: 0.106, alpha: 1)
        }
    }

    // MARK: - Cards / secondary surfaces

    var surfaceLight: UIColor {
        switch self {
        case .azzurro: return UIColor(red: 0.796, green: 0.886, blue: 0.961, alpha: 1)
        case .tramonto: return UIColor(red: 0.973, green: 0.878, blue: 0.784, alpha: 1)
        case .rosa: return UIColor(red: 0.965, green: 0.855, blue: 0.898, alpha: 1)
        case .smeraldo: return UIColor(red: 0.812, green: 0.910, blue: 0.867, alpha: 1)
        case .viola: return UIColor(red: 0.882, green: 0.851, blue: 0.953, alpha: 1)
        case .grafite: return UIColor(red: 0.867, green: 0.886, blue: 0.910, alpha: 1)
        }
    }

    var surfaceDark: UIColor {
        switch self {
        case .azzurro: return UIColor(red: 0.118, green: 0.153, blue: 0.212, alpha: 1)
        case .tramonto: return UIColor(red: 0.184, green: 0.141, blue: 0.106, alpha: 1)
        case .rosa: return UIColor(red: 0.188, green: 0.125, blue: 0.153, alpha: 1)
        case .smeraldo: return UIColor(red: 0.098, green: 0.169, blue: 0.145, alpha: 1)
        case .viola: return UIColor(red: 0.145, green: 0.125, blue: 0.208, alpha: 1)
        case .grafite: return UIColor(red: 0.133, green: 0.145, blue: 0.165, alpha: 1)
        }
    }

    /// Adaptive swatch color used in the settings picker.
    var swatch: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? primaryDark : primaryLight
        })
    }
}
