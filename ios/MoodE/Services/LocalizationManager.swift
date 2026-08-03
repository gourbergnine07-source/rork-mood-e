//
//  LocalizationManager.swift
//  MoodE
//

import Foundation
import SwiftUI
import Observation

/// Languages supported by the app UI and TMDB content.
enum AppLanguage: String, CaseIterable, Identifiable {
    case italiano = "it"
    case english = "en"
    case espanol = "es"
    case francais = "fr"

    var id: String { rawValue }

    /// Language name shown in its own language.
    var nativeName: String {
        switch self {
        case .italiano: return "Italiano"
        case .english: return "English"
        case .espanol: return "Español"
        case .francais: return "Français"
        }
    }

    var flag: String {
        switch self {
        case .italiano: return "🇮🇹"
        case .english: return "🇬🇧"
        case .espanol: return "🇪🇸"
        case .francais: return "🇫🇷"
        }
    }

    /// Value for the TMDB "language" query parameter.
    var tmdbCode: String {
        switch self {
        case .italiano: return "it-IT"
        case .english: return "en-US"
        case .espanol: return "es-ES"
        case .francais: return "fr-FR"
        }
    }

    /// Locale used for dates and decimal separators.
    var locale: Locale {
        switch self {
        case .italiano: return Locale(identifier: "it_IT")
        case .english: return Locale(identifier: "en_US")
        case .espanol: return Locale(identifier: "es_ES")
        case .francais: return Locale(identifier: "fr_FR")
        }
    }
}

/// Thread-safe string tables loaded once from the bundled it/en/es/fr JSON files.
/// Usable from nonisolated contexts (errors, cache, Codable helpers).
nonisolated enum L10nStore {
    static let storageKey = "app.language"

    private static let tables: [String: [String: String]] = {
        var result: [String: [String: String]] = [:]
        for code in ["it", "en", "es", "fr"] {
            guard let url = Bundle.main.url(forResource: code, withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
                print("[L10n] Missing or invalid table for \(code)")
                continue
            }
            result[code] = dict
        }
        return result
    }()

    /// Persisted language code, or the detected system language.
    static var currentCode: String {
        UserDefaults.standard.string(forKey: storageKey) ?? detectedCode
    }

    /// System language mapped to a supported one; English is the fallback.
    static var detectedCode: String {
        let preferred = Locale.preferredLanguages.first?.prefix(2).lowercased() ?? "en"
        return ["it", "es", "fr", "en"].contains(preferred) ? String(preferred) : "en"
    }

    static var currentLocale: Locale {
        AppLanguage(rawValue: currentCode)?.locale ?? Locale(identifier: "en_US")
    }

    /// Key lookup with English fallback; returns the key itself when unknown.
    static func string(_ key: String, language: String) -> String {
        tables[language]?[key] ?? tables["en"]?[key] ?? key
    }

    /// Rating like "7,5" or "7.5" depending on the language's decimal separator.
    static func rating(_ value: Double) -> String {
        String(format: "%.1f", locale: currentLocale, value)
    }
}

/// Localized string for nonisolated contexts (errors, models, notifications built off-main).
nonisolated func LN(_ key: String) -> String {
    L10nStore.string(key, language: L10nStore.currentCode)
}

/// Holds the user's chosen language; changing it re-renders every view
/// that reads localized strings during body evaluation.
@Observable
final class LocalizationManager {
    static let shared = LocalizationManager()

    var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: L10nStore.storageKey)
            Self.syncSystemLanguage(language)
            if oldValue != language {
                AnalyticsService.shared.log("language_selected", meta: ["lang": language.rawValue])
            }
        }
    }

    /// Keeps system-provided text (permission prompts, StoreKit and share
    /// sheets) in the language chosen inside the app. Without this, iOS picks
    /// the device language and the prompts can differ from the app UI.
    private static func syncSystemLanguage(_ language: AppLanguage) {
        UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
    }

    /// True once the user confirmed a language in the first-launch screen.
    var hasChosenLanguage: Bool {
        didSet { UserDefaults.standard.set(hasChosenLanguage, forKey: Self.chosenKey) }
    }

    private static let chosenKey = "app.language.chosen"

    private init() {
        let stored = UserDefaults.standard.string(forKey: L10nStore.storageKey)
        language = AppLanguage(rawValue: stored ?? "")
            ?? AppLanguage(rawValue: L10nStore.detectedCode)
            ?? .english
        hasChosenLanguage = UserDefaults.standard.bool(forKey: Self.chosenKey)
        Self.syncSystemLanguage(language)
    }

    func t(_ key: String) -> String {
        L10nStore.string(key, language: language.rawValue)
    }

    var locale: Locale { language.locale }

    /// Localized rating string (7,5 vs 7.5).
    func rating(_ value: Double) -> String {
        String(format: "%.1f", locale: language.locale, value)
    }
}

/// Localized string for SwiftUI views. Reads the observable language,
/// so views re-render automatically when the user switches language.
func L(_ key: String) -> String {
    LocalizationManager.shared.t(key)
}

/// Localized format string (e.g. "Step %d of 3").
func LF(_ key: String, _ args: CVarArg...) -> String {
    String(
        format: LocalizationManager.shared.t(key),
        locale: LocalizationManager.shared.locale,
        arguments: args
    )
}
