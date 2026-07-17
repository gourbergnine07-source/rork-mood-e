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

    /// Italian genre names resolved from TMDB genre IDs.
    var genreNames: [String] {
        (genreIds ?? []).compactMap { TMDBGenreCatalog.italianName(for: $0) }
    }

    /// Release year extracted from the release date (e.g. "1994").
    var releaseYear: String? {
        guard let releaseDate, releaseDate.count >= 4 else { return nil }
        return String(releaseDate.prefix(4))
    }

    /// Release date formatted in Italian (e.g. "12 giugno 2026").
    var formattedReleaseDate: String? {
        guard let releaseDate else { return nil }
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")
        guard let date = parser.date(from: releaseDate) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
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
            lines.append("\u{2B50} \(String(format: "%.1f", voteAverage))/10 su TMDB")
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

/// Italian display names for TMDB movie genre IDs.
nonisolated enum TMDBGenreCatalog {
    private static let names: [Int: String] = [
        28: "Azione", 12: "Avventura", 16: "Animazione", 35: "Commedia",
        80: "Crime", 99: "Documentario", 18: "Dramma", 10751: "Famiglia",
        14: "Fantasy", 36: "Storia", 27: "Horror", 10402: "Musica",
        9648: "Mistero", 10749: "Romantico", 878: "Fantascienza",
        53: "Thriller", 10752: "Guerra", 37: "Western", 10770: "Film TV"
    ]

    static func italianName(for id: Int) -> String? { names[id] }
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
