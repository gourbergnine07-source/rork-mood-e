//
//  TMDBTVShow.swift
//  MoodE
//

import Foundation

/// TMDB list category backing the four "Emissioni televisive" sections.
nonisolated enum TVCategory: String, CaseIterable, Identifiable {
    case popular
    case airingToday = "airing_today"
    case onTheAir = "on_the_air"
    case topRated = "top_rated"

    var id: String { rawValue }

    /// Localized label shown in the category selector.
    var label: String {
        switch self {
        case .popular: return LN("tv.category.popular")
        case .airingToday: return LN("tv.category.airingToday")
        case .onTheAir: return LN("tv.category.onTheAir")
        case .topRated: return LN("tv.category.topRated")
        }
    }

    var icon: String {
        switch self {
        case .popular: return "chart.line.uptrend.xyaxis"
        case .airingToday: return "dot.radiowaves.left.and.right"
        case .onTheAir: return "antenna.radiowaves.left.and.right"
        case .topRated: return "star.fill"
        }
    }

    /// Schedule-driven categories also show the next-episode air date.
    var showsNextEpisode: Bool {
        self == .airingToday || self == .onTheAir
    }
}

/// TV show returned by the TMDB TV list endpoints.
nonisolated struct TMDBTVShow: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let overview: String
    let posterPath: String?
    let backdropPath: String?
    let firstAirDate: String?
    let voteAverage: Double
    let voteCount: Int
    let genreIds: [Int]?

    enum CodingKeys: String, CodingKey {
        case id, name, overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case firstAirDate = "first_air_date"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case genreIds = "genre_ids"
    }

    /// Localized genre names resolved from TMDB TV genre IDs.
    var genreNames: [String] {
        (genreIds ?? []).compactMap { TMDBGenreCatalog.name(for: $0) }
    }

    /// First-air year (e.g. "2019").
    var firstAirYear: String? {
        guard let firstAirDate, firstAirDate.count >= 4 else { return nil }
        return String(firstAirDate.prefix(4))
    }

    /// Copy with a replaced overview (used for the English fallback).
    func withOverview(_ overview: String) -> TMDBTVShow {
        TMDBTVShow(
            id: id,
            name: name,
            overview: overview,
            posterPath: posterPath,
            backdropPath: backdropPath,
            firstAirDate: firstAirDate,
            voteAverage: voteAverage,
            voteCount: voteCount,
            genreIds: genreIds
        )
    }

    /// Full URL for the poster image (w500).
    var posterURL: URL? {
        guard let posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")
    }

    /// Full URL for the backdrop image (w780).
    var backdropURL: URL? {
        guard let backdropPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w780\(backdropPath)")
    }

    /// Message with title and key info used by the system share sheet.
    var shareMessage: String {
        var lines: [String] = []

        var headline = "\u{1F4FA} \(name)"
        if let firstAirYear {
            headline += " (\(firstAirYear))"
        }
        lines.append(headline)

        if voteAverage > 0 {
            lines.append(String(format: LN("share.ratingFormat"), L10nStore.rating(voteAverage)))
        }

        if !genreNames.isEmpty {
            lines.append(genreNames.prefix(3).joined(separator: " \u{00B7} "))
        }

        if !overview.isEmpty {
            let snippet = overview.count > 180
                ? String(overview.prefix(180)).trimmingCharacters(in: .whitespacesAndNewlines) + "\u{2026}"
                : overview
            lines.append(snippet)
        }

        lines.append("https://www.themoviedb.org/tv/\(id)")
        return lines.joined(separator: "\n")
    }
}

/// Paginated response from the TMDB TV list endpoints.
nonisolated struct TMDBTVShowListResponse: Codable {
    let page: Int
    let results: [TMDBTVShow]
    let totalPages: Int
    let totalResults: Int

    enum CodingKeys: String, CodingKey {
        case page, results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}

/// Episode info attached to a TV detail (`next_episode_to_air`).
nonisolated struct TMDBTVEpisodeInfo: Codable, Hashable {
    let airDate: String?
    let seasonNumber: Int?
    let episodeNumber: Int?
    let name: String?

    enum CodingKeys: String, CodingKey {
        case name
        case airDate = "air_date"
        case seasonNumber = "season_number"
        case episodeNumber = "episode_number"
    }

    /// Air date formatted in the user's language (e.g. "24 luglio").
    /// The broadcast time is appended ONLY when TMDB actually returns a
    /// date-time value (rare) — it is never invented or approximated.
    var formattedNextAiring: String? {
        guard let airDate, !airDate.isEmpty else { return nil }
        let locale = L10nStore.currentLocale

        if airDate.contains("T") {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime]
            var parsed = iso.date(from: airDate)
            if parsed == nil {
                iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                parsed = iso.date(from: airDate)
            }
            if let date = parsed {
                let day = DateFormatter()
                day.locale = locale
                day.setLocalizedDateFormatFromTemplate("d MMMM")
                let time = DateFormatter()
                time.locale = locale
                time.setLocalizedDateFormatFromTemplate("HH:mm")
                return "\(day.string(from: date)), \(time.string(from: date))"
            }
        }

        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")
        guard let date = parser.date(from: String(airDate.prefix(10))) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("d MMMM")
        return formatter.string(from: date)
    }

    /// Compact "S2 · E5" episode reference.
    var episodeReference: String? {
        guard let seasonNumber, let episodeNumber else { return nil }
        return "S\(seasonNumber) \u{00B7} E\(episodeNumber)"
    }
}

/// Lightweight envelope to decode only `next_episode_to_air` from /tv/{id},
/// used by the lazy per-card lookup without paying for the full detail.
nonisolated struct TMDBTVNextEpisodeEnvelope: Codable {
    let nextEpisodeToAir: TMDBTVEpisodeInfo?

    enum CodingKeys: String, CodingKey {
        case nextEpisodeToAir = "next_episode_to_air"
    }
}
