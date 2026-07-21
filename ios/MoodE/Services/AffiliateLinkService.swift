//
//  AffiliateLinkService.swift
//  MoodE
//

import Foundation

/// Central place for affiliate/monetization links (rent & buy),
/// separate from and complementary to AdMob advertising.
///
/// IMPORTANT — affiliate IDs status:
/// - `appleAffiliateID`: PLACEHOLDER — replace with the token from Apple
///   Services Performance Partners (https://performance-partners.apple.com).
///   Final per-title URL format:
///   https://tv.apple.com/movie/[movie-id]?at=[AFFILIATE_ID]
/// - `amazonAssociateTag`: REAL tag `moode26-21` (Amazon Associates,
///   registered on amazon.it — commissions track on the .it marketplace).
///   Final per-title URL format:
///   https://www.amazon.it/dp/[asin]?tag=moode26-21
///
/// Until we resolve real per-title IDs (e.g. via a JustWatch-like service),
/// links point to the store SEARCH page for the movie title + year, keeping
/// the affiliate parameter in place so tracking works from day one.
enum AffiliateLinks {
    /// Apple Services Performance Partners token (placeholder).
    static let appleAffiliateID = "AFFILIATE_ID"
    /// Amazon Associates tag (amazon.it). If you later register other
    /// marketplaces (es/fr/com), map one tag per host in `amazonTag(for:)`.
    static let amazonAssociateTag = "moode26-21"

    /// Apple TV / iTunes affiliate link for a movie.
    /// Search-based fallback until real per-title Apple IDs are wired in.
    static func appleTVURL(title: String, year: String?) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "tv.apple.com"
        components.path = "/\(storefront)/search"
        components.queryItems = [
            URLQueryItem(name: "term", value: searchTerm(title: title, year: year)),
            URLQueryItem(name: "at", value: appleAffiliateID)
        ]
        return components.url
    }

    /// Amazon (Prime Video rent/buy) affiliate link for a movie.
    /// Search-based fallback until real ASINs are wired in.
    static func amazonURL(title: String, year: String?) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = amazonHost
        components.path = "/s"
        components.queryItems = [
            URLQueryItem(name: "k", value: searchTerm(title: title, year: year)),
            URLQueryItem(name: "i", value: "instant-video"),
            URLQueryItem(name: "tag", value: amazonTag(for: amazonHost))
        ]
        return components.url
    }

    /// Associates tag per marketplace. The `moode26-21` tag is registered
    /// on amazon.it; add entries here once other marketplaces are approved
    /// so every locale earns commissions.
    private static let amazonTagsByHost: [String: String] = [
        "www.amazon.it": amazonAssociateTag
    ]

    private static func amazonTag(for host: String) -> String {
        amazonTagsByHost[host] ?? amazonAssociateTag
    }

    // MARK: - Region handling

    /// Apple TV web storefront matching the app language.
    private static var storefront: String {
        switch LocalizationManager.shared.language.rawValue {
        case "it": return "it"
        case "es": return "es"
        case "fr": return "fr"
        default: return "us"
        }
    }

    /// Amazon marketplace matching the app language.
    /// Note: Amazon Associates tags are per-marketplace; when the real
    /// tags arrive, map one tag per host here.
    private static var amazonHost: String {
        switch LocalizationManager.shared.language.rawValue {
        case "it": return "www.amazon.it"
        case "es": return "www.amazon.es"
        case "fr": return "www.amazon.fr"
        default: return "www.amazon.com"
        }
    }

    private static func searchTerm(title: String, year: String?) -> String {
        guard let year, !year.isEmpty else { return title }
        return "\(title) \(year)"
    }
}
