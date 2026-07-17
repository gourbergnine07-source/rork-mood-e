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
    static let crime = 80
    static let documentary = 99
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
    static let war = 10752
}

/// TMDB keyword IDs used to sharpen specific mood × goal combinations.
enum TMDBKeyword {
    static let basedOnTrueStory = 9672
    static let biography = 5565
    static let sport = 6075
    static let timeTravel = 4379
}

/// Genres and keywords derived from the mood × goal mapping table.
struct RecommendationQuery {
    var genres: [Int]
    var keywords: [Int] = []
    var allowsHorror: Bool = false
}

/// Networking service for The Movie Database (api.themoviedb.org/3).
enum TMDBService {
    private static let baseURL = "https://api.themoviedb.org/3"
    private static let language = "it-IT"

    /// Discovers movies matching the user's mood, goal and era choices.
    /// Returns the full paginated response so callers can request fresh pages.
    static func discoverMovies(for selection: MoodSelection, page: Int = 1) async throws -> TMDBMovieListResponse {
        let recommendation = recommendationQuery(mood: selection.mood, goal: selection.goal)

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "sort_by", value: "vote_average.desc"),
            URLQueryItem(name: "vote_count.gte", value: "300"),
            URLQueryItem(name: "include_adult", value: "false"),
            URLQueryItem(name: "with_genres", value: recommendation.genres.map(String.init).joined(separator: "|")),
            URLQueryItem(name: "page", value: String(page))
        ]

        if !recommendation.keywords.isEmpty {
            queryItems.append(URLQueryItem(
                name: "with_keywords",
                value: recommendation.keywords.map(String.init).joined(separator: "|")
            ))
        }

        if !recommendation.allowsHorror && selection.mood != .impaurito {
            queryItems.append(URLQueryItem(name: "without_genres", value: String(TMDBGenre.horror)))
        }

        let dateRange = Self.dateRange(for: selection.era)
        if let gte = dateRange.gte {
            queryItems.append(URLQueryItem(name: "primary_release_date.gte", value: gte))
        }
        if let lte = dateRange.lte {
            queryItems.append(URLQueryItem(name: "primary_release_date.lte", value: lte))
        }

        return try await request(path: "/discover/movie", queryItems: queryItems)
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

    /// Full mapping table (12 moods × 10 goals): the goal drives the primary
    /// genres, the mood refines the mix with extra genres or TMDB keywords.
    private static func recommendationQuery(mood: Mood, goal: ViewingGoal) -> RecommendationQuery {
        var query: RecommendationQuery

        switch goal {
        case .ridere:
            query = RecommendationQuery(genres: [TMDBGenre.comedy])
            switch mood {
            case .felice, .motivato: query.genres += [TMDBGenre.adventure]
            case .triste, .malinconico: query.genres += [TMDBGenre.drama]
            case .stressato, .nostalgico: query.genres += [TMDBGenre.family]
            case .annoiato, .arrabbiato: query.genres += [TMDBGenre.action]
            case .innamorato: query.genres += [TMDBGenre.romance]
            case .spensierato: query.genres += [TMDBGenre.animation]
            case .curioso: query.genres += [TMDBGenre.crime]
            case .impaurito:
                query.genres += [TMDBGenre.horror]
                query.allowsHorror = true
            }

        case .piangere:
            query = RecommendationQuery(genres: [TMDBGenre.drama])
            switch mood {
            case .triste, .innamorato, .malinconico, .felice: query.genres += [TMDBGenre.romance]
            case .stressato, .spensierato, .nostalgico: query.genres += [TMDBGenre.family]
            case .annoiato, .arrabbiato: query.genres += [TMDBGenre.war]
            case .motivato:
                query.genres += [TMDBGenre.history]
                query.keywords = [TMDBKeyword.basedOnTrueStory]
            case .curioso: query.genres += [TMDBGenre.mystery]
            case .impaurito: query.genres += [TMDBGenre.thriller]
            }

        case .rilassarmi:
            query = RecommendationQuery(genres: [TMDBGenre.animation, TMDBGenre.comedy, TMDBGenre.family])
            switch mood {
            case .innamorato, .malinconico: query.genres += [TMDBGenre.romance]
            case .curioso, .annoiato: query.genres += [TMDBGenre.adventure]
            case .nostalgico: query.genres += [TMDBGenre.music]
            default: break
            }

        case .riflettere:
            query = RecommendationQuery(genres: [TMDBGenre.drama, TMDBGenre.mystery, TMDBGenre.history])
            switch mood {
            case .curioso, .annoiato: query.genres += [TMDBGenre.sciFi]
            case .arrabbiato: query.genres += [TMDBGenre.crime]
            case .motivato: query.keywords = [TMDBKeyword.basedOnTrueStory]
            case .impaurito: query.genres += [TMDBGenre.thriller]
            default: break
            }

        case .emozionarmi:
            query = RecommendationQuery(genres: [TMDBGenre.drama, TMDBGenre.adventure])
            switch mood {
            case .innamorato, .malinconico, .triste, .nostalgico: query.genres += [TMDBGenre.romance]
            case .annoiato, .arrabbiato: query.genres += [TMDBGenre.action]
            case .curioso: query.genres += [TMDBGenre.mystery]
            case .spensierato, .felice: query.genres += [TMDBGenre.music]
            case .motivato: query.keywords = [TMDBKeyword.sport, TMDBKeyword.basedOnTrueStory]
            case .stressato, .impaurito: query.genres += [TMDBGenre.thriller]
            }

        case .distrarmi:
            query = RecommendationQuery(genres: [TMDBGenre.action, TMDBGenre.adventure, TMDBGenre.comedy])
            switch mood {
            case .curioso: query.genres += [TMDBGenre.sciFi]
            case .impaurito: query.genres += [TMDBGenre.thriller]
            case .spensierato, .stressato: query.genres += [TMDBGenre.animation]
            case .nostalgico: query.genres += [TMDBGenre.family]
            case .arrabbiato: query.genres += [TMDBGenre.crime]
            default: break
            }

        case .ispirarmi:
            query = RecommendationQuery(
                genres: [TMDBGenre.drama, TMDBGenre.history, TMDBGenre.documentary],
                keywords: [TMDBKeyword.basedOnTrueStory, TMDBKeyword.biography, TMDBKeyword.sport]
            )
            switch mood {
            case .innamorato, .malinconico: query.genres += [TMDBGenre.romance]
            case .spensierato, .felice: query.genres += [TMDBGenre.music]
            default: break
            }

        case .paura:
            query = RecommendationQuery(genres: [TMDBGenre.horror, TMDBGenre.thriller], allowsHorror: true)
            switch mood {
            case .curioso, .triste, .malinconico: query.genres += [TMDBGenre.mystery]
            case .arrabbiato: query.genres += [TMDBGenre.crime]
            default: break
            }

        case .sognare:
            query = RecommendationQuery(genres: [TMDBGenre.fantasy, TMDBGenre.sciFi, TMDBGenre.adventure])
            switch mood {
            case .innamorato, .malinconico: query.genres += [TMDBGenre.romance]
            case .nostalgico: query.keywords = [TMDBKeyword.timeTravel]
            case .spensierato, .felice, .stressato: query.genres += [TMDBGenre.animation]
            default: break
            }

        case .innamorarmi:
            query = RecommendationQuery(genres: [TMDBGenre.romance])
            switch mood {
            case .felice, .spensierato, .annoiato: query.genres += [TMDBGenre.comedy]
            case .curioso: query.genres += [TMDBGenre.fantasy]
            case .nostalgico: query.genres += [TMDBGenre.music]
            case .impaurito: query.genres += [TMDBGenre.thriller]
            default: query.genres += [TMDBGenre.drama]
            }
        }

        return query
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
