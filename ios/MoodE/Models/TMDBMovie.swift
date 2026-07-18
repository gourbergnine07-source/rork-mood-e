//
//  TMDBMovie.swift
//  MoodE
//

import Foundation

/// Movie returned by the TMDB API.
nonisolated struct TMDBMovie: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let overview: String
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let voteAverage: Double
    let voteCount: Int
    let genreIds: [Int]?

    enum CodingKeys: String, CodingKey {
        case id, title, overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case genreIds = "genre_ids"
    }

    /// Localized genre names resolved from TMDB genre IDs.
    var genreNames: [String] {
        (genreIds ?? []).compactMap { TMDBGenreCatalog.name(for: $0) }
    }

    /// Release year extracted from the release date (e.g. "1994").
    var releaseYear: String? {
        guard let releaseDate, releaseDate.count >= 4 else { return nil }
        return String(releaseDate.prefix(4))
    }

    /// Release date formatted in the user's language, with the day/month
    /// order adapted per locale (e.g. "12 giugno 2026" vs "June 12, 2026").
    var formattedReleaseDate: String? {
        guard let releaseDate else { return nil }
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")
        guard let date = parser.date(from: releaseDate) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = L10nStore.currentLocale
        formatter.setLocalizedDateFormatFromTemplate("d MMMM yyyy")
        return formatter.string(from: date)
    }

    /// Copy with a replaced overview (used for the English fallback).
    func withOverview(_ overview: String) -> TMDBMovie {
        TMDBMovie(
            id: id,
            title: title,
            overview: overview,
            posterPath: posterPath,
            backdropPath: backdropPath,
            releaseDate: releaseDate,
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

        var headline = "\u{1F3AC} \(title)"
        if let releaseYear {
            headline += " (\(releaseYear))"
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

        lines.append("https://www.themoviedb.org/movie/\(id)")
        return lines.joined(separator: "\n")
    }
}

/// Localized display names for TMDB movie genre IDs (from the language tables).
nonisolated enum TMDBGenreCatalog {
    /// Localized genre name, or nil when the ID is unknown.
    static func name(for id: Int) -> String? {
        let key = "genre.\(id)"
        let value = LN(key)
        return value == key ? nil : value
    }
}

/// Paginated list response from TMDB endpoints (discover, trending, now playing).
nonisolated struct TMDBMovieListResponse: Codable {
    let page: Int
    let results: [TMDBMovie]
    let totalPages: Int
    let totalResults: Int

    enum CodingKeys: String, CodingKey {
        case page, results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}
