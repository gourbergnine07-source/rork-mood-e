//
//  AffiliateLinkService.swift
//  MoodE
//
//  Affiliate links and provider tap routing.
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
///   Final per-title URL format (when the Prime Video ASIN is known):
///   https://www.amazon.it/dp/[asin]?tag=moode26-21 — see `amazonTitleURL`.
///
/// Until we resolve real per-title IDs (e.g. via a JustWatch-like service),
/// links point to the store SEARCH page for the movie title + year, keeping
/// the affiliate parameter in place so tracking works from day one.
///
/// Prime Video note: the search fallback deliberately targets
/// www.primevideo.com (streaming-only storefront, geo-localized by Amazon
/// for every market) instead of the amazon.xx marketplace search, which
/// mixes in physical DVDs/merchandise even with the instant-video filter.
/// Earnings note (developer-facing): the Prime Video program pays mostly
/// as fixed bounties for trial sign-ups plus a flat "Movies" rate on
/// eligible digital purchases — not the variable physical-goods rates.
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
    /// Lands on Prime Video search results — streaming/rent/buy only,
    /// never the generic Amazon shopping marketplace. primevideo.com is a
    /// single worldwide host that Amazon geo-localizes per market, so the
    /// same URL is correct for it/es/fr/en users.
    static func amazonURL(title: String, year: String?) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.primevideo.com"
        components.path = "/search/ref=atv_nb_sr"
        components.queryItems = [
            URLQueryItem(name: "phrase", value: searchTerm(title: title, year: year)),
            URLQueryItem(name: "tag", value: amazonTag(for: amazonHost))
        ]
        return components.url
    }

    /// Direct Prime Video detail page for a title whose ASIN is known
    /// (10-char id, different per marketplace). Preferred over the search
    /// fallback whenever an ASIN resolver is wired in.
    static func amazonTitleURL(asin: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = amazonHost
        components.path = "/dp/\(asin)"
        components.queryItems = [
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

    // MARK: - Provider routing (Netflix, Disney+, etc. via TMDB/JustWatch)

    /// Where a tap on a watch-provider logo should lead.
    struct ProviderDestination {
        enum Kind {
            /// One of our affiliate programs (earns a commission).
            case affiliate
            /// TMDB/JustWatch deep link for the title (no affiliate active).
            case justWatch
        }

        let url: URL
        let kind: Kind
        /// Analytics label (e.g. "amazon", "apple_tv", "justwatch").
        let store: String
    }

    /// Routes a provider tap: Amazon/Prime and Apple/iTunes go through our
    /// affiliate links; every other platform (Netflix, Disney+, …) opens
    /// the TMDB/JustWatch page for the title, which deep-links to each
    /// service's own page for the movie.
    static func providerDestination(
        for provider: TMDBWatchProvider,
        title: String,
        year: String?,
        justWatchLink: URL?
    ) -> ProviderDestination? {
        let name = provider.providerName.lowercased()

        if name.contains("amazon") || name.contains("prime video") {
            if let url = amazonURL(title: title, year: year) {
                return ProviderDestination(url: url, kind: .affiliate, store: "amazon")
            }
        }

        if name.contains("apple") || name.contains("itunes") {
            if let url = appleTVURL(title: title, year: year) {
                return ProviderDestination(url: url, kind: .affiliate, store: "apple_tv")
            }
        }

        guard let justWatchLink else { return nil }
        return ProviderDestination(url: justWatchLink, kind: .justWatch, store: "justwatch")
    }
}
