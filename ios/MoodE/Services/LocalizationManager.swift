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
    case deutsch = "de"
    case portugues = "pt"

    var id: String { rawValue }

    /// Language name shown in its own language.
    var nativeName: String {
        switch self {
        case .italiano: return "Italiano"
        case .english: return "English"
        case .espanol: return "Español"
        case .francais: return "Français"
        case .deutsch: return "Deutsch"
        case .portugues: return "Português"
        }
    }

    var flag: String {
        switch self {
        case .italiano: return "🇮🇹"
        case .english: return "🇬🇧"
        case .espanol: return "🇪🇸"
        case .francais: return "🇫🇷"
        case .deutsch: return "🇩🇪"
        case .portugues: return "🇵🇹"
        }
    }

    /// Value for the TMDB "language" query parameter. Portuguese uses the
    /// European variant; a separate pt-BR case can be added later if the
    /// Brazilian market gets its own entry.
    var tmdbCode: String {
        switch self {
        case .italiano: return "it-IT"
        case .english: return "en-US"
        case .espanol: return "es-ES"
        case .francais: return "fr-FR"
        case .deutsch: return "de-DE"
        case .portugues: return "pt-PT"
        }
    }

    /// Country used for release dates, cinema listings and streaming
    /// availability when the device region is unknown.
    var region: String {
        switch self {
        case .italiano: return "IT"
        case .english: return "US"
        case .espanol: return "ES"
        case .francais: return "FR"
        case .deutsch: return "DE"
        case .portugues: return "PT"
        }
    }

    /// Locale used for dates and decimal separators.
    var locale: Locale {
        switch self {
        case .italiano: return Locale(identifier: "it_IT")
        case .english: return Locale(identifier: "en_US")
        case .espanol: return Locale(identifier: "es_ES")
        case .francais: return Locale(identifier: "fr_FR")
        case .deutsch: return Locale(identifier: "de_DE")
        case .portugues: return Locale(identifier: "pt_PT")
        }
    }
}

/// Thread-safe string tables loaded once from the bundled JSON files, one per
/// supported language. Usable from nonisolated contexts (errors, cache,
/// Codable helpers).
nonisolated enum L10nStore {
    static let storageKey = "app.language"

    /// Language codes with a bundled string table; mirrors `AppLanguage`.
    static let supportedCodes: [String] = ["it", "en", "es", "fr", "de", "pt"]

    private static let tables: [String: [String: String]] = {
        var result: [String: [String: String]] = [:]
        for code in supportedCodes {
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
    /// Every Portuguese variant (pt-BR, pt-PT) maps to the single `pt` table.
    static var detectedCode: String {
        let preferred = Locale.preferredLanguages.first?.prefix(2).lowercased() ?? "en"
        return supportedCodes.contains(String(preferred)) ? String(preferred) : "en"
    }

    /// Region matching the persisted language, used by nonisolated callers.
    static var currentRegion: String {
        AppLanguage(rawValue: currentCode)?.region ?? "US"
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
    /// The new value only takes effect on the next launch, because the bundle
    /// resolves its localization once at process start.
    private static func syncSystemLanguage(_ language: AppLanguage) {
        UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
    }

    /// Language iOS is actually using for system-rendered text in THIS launch
    /// (permission alerts, StoreKit sheets), taken from the loaded bundle.
    var systemTextLanguage: String {
        let localization = Bundle.main.preferredLocalizations.first ?? "en"
        return String(localization.prefix(2)).lowercased()
    }

    /// False while a system alert would appear in a different language than the
    /// app UI — happens on the launch where the user picks a language that
    /// differs from the device one. App Store guideline 4 requires permission
    /// prompts to match the app's localization, so callers must postpone them
    /// until this is true (i.e. from the next launch on).
    var canShowSystemPrompts: Bool {
        systemTextLanguage == language.rawValue
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
