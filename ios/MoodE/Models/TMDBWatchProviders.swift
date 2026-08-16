//
//  TMDBWatchProviders.swift
//  MoodE
//

import Foundation

/// "watch/providers" payload appended to a TMDB movie detail:
/// per-country availability grouped by monetization type.
nonisolated struct TMDBWatchProviderResults: Codable, Hashable {
    let results: [String: TMDBWatchProviderRegion]

    /// Provider group for the most relevant region: device region first,
    /// then the app-language default, then US. Returns nil when nothing
    /// meaningful is available (the section is simply hidden).
    var bestRegion: TMDBWatchProviderRegion? {
        let languageRegion = L10nStore.currentRegion

        var candidates: [String] = []
        if let device = Locale.current.region?.identifier {
            candidates.append(device)
        }
        candidates.append(contentsOf: [languageRegion, "US"])

        for code in candidates {
            if let region = results[code], region.hasAny {
                return region
            }
        }
        return nil
    }
}

/// Availability in a single country: JustWatch link plus provider lists.
nonisolated struct TMDBWatchProviderRegion: Codable, Hashable {
    let link: String?
    let flatrate: [TMDBWatchProvider]?
    let rent: [TMDBWatchProvider]?
    let buy: [TMDBWatchProvider]?

    var hasAny: Bool {
        !(flatrate ?? []).isEmpty || !(rent ?? []).isEmpty || !(buy ?? []).isEmpty
    }

    /// JustWatch page (via TMDB) listing every viewing option.
    var linkURL: URL? {
        guard let link else { return nil }
        return URL(string: link)
    }
}

/// Single streaming/rent/buy provider (e.g. Netflix, Prime Video).
nonisolated struct TMDBWatchProvider: Codable, Identifiable, Hashable {
    let providerId: Int
    let providerName: String
    let logoPath: String?
    let displayPriority: Int?

    var id: Int { providerId }

    enum CodingKeys: String, CodingKey {
        case providerId = "provider_id"
        case providerName = "provider_name"
        case logoPath = "logo_path"
        case displayPriority = "display_priority"
    }

    /// Provider logo URL (w92).
    var logoURL: URL? {
        guard let logoPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w92\(logoPath)")
    }
}
