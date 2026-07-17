//
//  TMDBService.swift
//  MoodE
//

import Foundation

/// Errors surfaced by the TMDB networking layer.
nonisolated enum TMDBError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case badResponse(statusCode: Int)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Chiave API TMDB mancante. Configurala nelle impostazioni del progetto."
        case .invalidURL:
            return "Indirizzo della richiesta non valido."
        case .badResponse(let statusCode):
            return "TMDB ha risposto con un errore (codice \(statusCode)). Riprova tra poco."
        case .decodingFailed:
            return "Non sono riuscito a leggere i dati dei film. Riprova."
        }
    }
}

/// TMDB genre IDs used to translate moods and goals into queries.
enum TMDBGenre {
    static let action = 28
    static let adventure = 12
    static let animation = 16
    static let comedy = 35
    static let drama = 18
    static let family = 10751
    static let fantasy = 14
    static let history = 36
    static let horror = 27
    static let music = 10402
    static let mystery = 9648
    static let romance = 10749
    static let sciFi = 878
    static let thriller = 53
}

/// Networking service for The Movie Database (api.themoviedb.org/3).
enum TMDBService {
    private static let baseURL = "https://api.themoviedb.org/3"
    private static let language = "it-IT"

    /// Discovers movies matching the user's mood, goal and era choices.
    static func discoverMovies(for selection: MoodSelection, page: Int = 1) async throws -> [TMDBMovie] {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "sort_by", value: "vote_average.desc"),
            URLQueryItem(name: "vote_count.gte", value: "300"),
            URLQueryItem(name: "include_adult", value: "false"),
            URLQueryItem(name: "with_genres", value: genreQuery(for: selection)),
            URLQueryItem(name: "page", value: String(page))
        ]

        if let excluded = excludedGenres(for: selection) {
            queryItems.append(URLQueryItem(name: "without_genres", value: excluded))
        }

        let dateRange = Self.dateRange(for: selection.era)
        if let gte = dateRange.gte {
            queryItems.append(URLQueryItem(name: "primary_release_date.gte", value: gte))
        }
        if let lte = dateRange.lte {
            queryItems.append(URLQueryItem(name: "primary_release_date.lte", value: lte))
        }

        let response: TMDBMovieListResponse = try await request(path: "/discover/movie", queryItems: queryItems)
        return response.results
    }

    /// Trending movies of the week.
    static func trendingMovies() async throws -> [TMDBMovie] {
        let response: TMDBMovieListResponse = try await request(path: "/trending/movie/week", queryItems: [])
        return response.results
    }

    /// Movies currently playing in theatres (region-aware).
    static func nowPlayingMovies(region: String = "IT") async throws -> [TMDBMovie] {
        let queryItems = [URLQueryItem(name: "region", value: region)]
        let response: TMDBMovieListResponse = try await request(path: "/movie/now_playing", queryItems: queryItems)
        return response.results
    }

    /// Full movie detail with cast and videos in a single call.
    static func movieDetail(id: Int) async throws -> TMDBMovieDetail {
        let queryItems = [
            URLQueryItem(name: "append_to_response", value: "credits,videos"),
            URLQueryItem(name: "include_video_language", value: "it,en")
        ]
        return try await request(path: "/movie/\(id)", queryItems: queryItems)
    }

    // MARK: - Core request

    private static func request<T: Decodable>(path: String, queryItems: [URLQueryItem]) async throws -> T {
        let apiKey = Config.EXPO_PUBLIC_TMDB_API_KEY
        guard !apiKey.isEmpty else { throw TMDBError.missingAPIKey }

        guard var components = URLComponents(string: baseURL + path) else {
            throw TMDBError.invalidURL
        }
        components.queryItems = queryItems + [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "language", value: language)
        ]

        guard let url = components.url else { throw TMDBError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TMDBError.badResponse(statusCode: -1)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw TMDBError.badResponse(statusCode: httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("[TMDB] Decoding error for \(path): \(error)")
            throw TMDBError.decodingFailed
        }
    }

    // MARK: - Selection → query mapping

    /// Combines goal (primary) and mood (secondary) genres with OR semantics.
    private static func genreQuery(for selection: MoodSelection) -> String {
        var genres = goalGenres(selection.goal)
        for genre in moodGenres(selection.mood) where !genres.contains(genre) {
            genres.append(genre)
        }
        return genres.map(String.init).joined(separator: "|")
    }

    private static func goalGenres(_ goal: ViewingGoal) -> [Int] {
        switch goal {
        case .ridere: return [TMDBGenre.comedy]
        case .piangere: return [TMDBGenre.drama, TMDBGenre.romance]
        case .rilassarmi: return [TMDBGenre.comedy, TMDBGenre.family, TMDBGenre.animation]
        case .riflettere: return [TMDBGenre.drama, TMDBGenre.mystery, TMDBGenre.history]
        case .emozionarmi: return [TMDBGenre.drama, TMDBGenre.adventure]
        case .distrarmi: return [TMDBGenre.action, TMDBGenre.adventure, TMDBGenre.comedy]
        case .ispirarmi: return [TMDBGenre.drama, TMDBGenre.history, TMDBGenre.music]
        case .paura: return [TMDBGenre.horror, TMDBGenre.thriller]
        case .sognare: return [TMDBGenre.fantasy, TMDBGenre.sciFi, TMDBGenre.adventure]
        case .innamorarmi: return [TMDBGenre.romance]
        }
    }

    private static func moodGenres(_ mood: Mood) -> [Int] {
        switch mood {
        case .felice: return [TMDBGenre.comedy]
        case .triste: return [TMDBGenre.drama]
        case .stressato: return [TMDBGenre.family]
        case .annoiato: return [TMDBGenre.action]
        case .innamorato: return [TMDBGenre.romance]
        case .nostalgico: return [TMDBGenre.family]
        case .arrabbiato: return [TMDBGenre.action]
        case .motivato: return [TMDBGenre.drama]
        case .malinconico: return [TMDBGenre.romance]
        case .spensierato: return [TMDBGenre.animation]
        case .curioso: return [TMDBGenre.mystery]
        case .impaurito: return [TMDBGenre.thriller]
        }
    }

    /// Keeps scary genres out of the results unless the user explicitly wants them.
    private static func excludedGenres(for selection: MoodSelection) -> String? {
        guard selection.goal != .paura, selection.mood != .impaurito else { return nil }
        return String(TMDBGenre.horror)
    }

    private static func dateRange(for era: MovieEra) -> (gte: String?, lte: String?) {
        switch era {
        case .seventiesEighties:
            return ("1970-01-01", "1989-12-31")
        case .nineties:
            return ("1990-01-01", "1999-12-31")
        case .twoThousands:
            return ("2000-01-01", "2010-12-31")
        case .lastFiveYears:
            let calendar = Calendar.current
            let now = Date()
            let fiveYearsAgo = calendar.date(byAdding: .year, value: -5, to: now) ?? now
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            return (formatter.string(from: fiveYearsAgo), nil)
        case .noPreference:
            return (nil, nil)
        }
    }
}
