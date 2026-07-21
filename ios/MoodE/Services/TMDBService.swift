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
            return LN("error.missingKey")
        case .invalidURL:
            return LN("error.invalidURL")
        case .badResponse(let statusCode):
            return String(format: LN("error.badResponse"), statusCode)
        case .decodingFailed:
            return LN("error.decoding")
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
    static let christmas = 207317
    static let lgbt = 158718
}

/// Genres and keywords derived from the mood × goal mapping table.
struct RecommendationQuery {
    var genres: [Int]
    var keywords: [Int] = []
    var allowsHorror: Bool = false
}

/// Time window supported by the TMDB trending endpoint.
nonisolated enum TrendingWindow: String, CaseIterable, Identifiable {
    case week
    case day

    var id: String { rawValue }

    /// Localized label shown in the trending selector.
    var label: String {
        switch self {
        case .week: return LN("trending.week")
        case .day: return LN("trending.day")
        }
    }
}

/// Networking service for The Movie Database (api.themoviedb.org/3).
enum TMDBService {
    private static let baseURL = "https://api.themoviedb.org/3"

    /// TMDB language parameter following the user's chosen language.
    private static var language: String { LocalizationManager.shared.language.tmdbCode }

    /// Trailer languages: user language first, English as fallback.
    private static var videoLanguageParam: String {
        let code = LocalizationManager.shared.language.rawValue
        return code == "en" ? "en" : "\(code),en"
    }

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

        let response: TMDBMovieListResponse = try await request(path: "/discover/movie", queryItems: queryItems)
        return await fillingMissingOverviews(response, path: "/discover/movie", queryItems: queryItems)
    }

    /// "Serata in Duo": movies crossing two mood × goal combinations.
    /// Shared genres are preferred; when the two profiles have nothing in
    /// common the union is used so the list is never empty.
    static func duoDiscover(
        hostMood: Mood, hostGoal: ViewingGoal,
        guestMood: Mood, guestGoal: ViewingGoal
    ) async throws -> [TMDBMovie] {
        let hostQuery = recommendationQuery(mood: hostMood, goal: hostGoal)
        let guestQuery = recommendationQuery(mood: guestMood, goal: guestGoal)

        let shared = Set(hostQuery.genres).intersection(guestQuery.genres)
        let genres = shared.isEmpty
            ? Array(Set(hostQuery.genres).union(guestQuery.genres))
            : Array(shared)

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "sort_by", value: "vote_average.desc"),
            URLQueryItem(name: "vote_count.gte", value: "300"),
            URLQueryItem(name: "include_adult", value: "false"),
            URLQueryItem(name: "with_genres", value: genres.map(String.init).joined(separator: "|")),
            URLQueryItem(name: "page", value: "1")
        ]
        if !hostQuery.allowsHorror && !guestQuery.allowsHorror {
            queryItems.append(URLQueryItem(name: "without_genres", value: String(TMDBGenre.horror)))
        }

        let response: TMDBMovieListResponse = try await request(path: "/discover/movie", queryItems: queryItems)
        let filled = await fillingMissingOverviews(response, path: "/discover/movie", queryItems: queryItems)
        return Array(filled.results.prefix(12))
    }

    /// Movies for an editorial collection of the "In evidenza" strip.
    /// Trending-backed collections reuse the weekly trending endpoint;
    /// discover-backed ones translate the collection's query into filters.
    /// Results vary between sessions: a random page is fetched and the
    /// list is shuffled so the collection feels fresh on every visit.
    static func featuredMovies(source: FeaturedSource) async throws -> [TMDBMovie] {
        switch source {
        case .trendingWeek:
            return try await trendingMovies(window: .week).shuffled()

        case .discover(let query):
            let page = Int.random(in: 1...4)
            let movies = try await discoverFeatured(query: query, page: page)
            // Narrow queries (e.g. Oscar race) may not fill deeper pages —
            // fall back to page 1 so the list is never sparse.
            if movies.count < 8 && page > 1 {
                return try await discoverFeatured(query: query, page: 1).shuffled()
            }
            return movies.shuffled()
        }
    }

    private static func discoverFeatured(query: FeaturedQuery, page: Int) async throws -> [TMDBMovie] {
            var queryItems: [URLQueryItem] = [
                URLQueryItem(name: "sort_by", value: query.sortBy),
                URLQueryItem(name: "vote_count.gte", value: String(query.voteCountGte)),
                URLQueryItem(name: "include_adult", value: "false"),
                URLQueryItem(name: "page", value: String(page))
            ]
            if !query.genres.isEmpty {
                queryItems.append(URLQueryItem(
                    name: "with_genres",
                    value: query.genres.map(String.init).joined(separator: "|")
                ))
            }
            if !query.keywords.isEmpty {
                queryItems.append(URLQueryItem(
                    name: "with_keywords",
                    value: query.keywords.map(String.init).joined(separator: "|")
                ))
            }
            if let voteAverageGte = query.voteAverageGte {
                queryItems.append(URLQueryItem(name: "vote_average.gte", value: String(voteAverageGte)))
            }
            if !query.includeHorror {
                queryItems.append(URLQueryItem(name: "without_genres", value: String(TMDBGenre.horror)))
            }
            if let months = query.releasedWithinMonths {
                let calendar = Calendar.current
                if let from = calendar.date(byAdding: .month, value: -months, to: Date()) {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    queryItems.append(URLQueryItem(
                        name: "primary_release_date.gte",
                        value: formatter.string(from: from)
                    ))
                }
            }

            let response: TMDBMovieListResponse = try await request(path: "/discover/movie", queryItems: queryItems)
            return await fillingMissingOverviews(response, path: "/discover/movie", queryItems: queryItems).results
    }

    /// Trending movies for the requested time window (week or day).
    static func trendingMovies(window: TrendingWindow = .week) async throws -> [TMDBMovie] {
        let path = "/trending/movie/\(window.rawValue)"
        let response: TMDBMovieListResponse = try await request(path: path, queryItems: [])
        return await fillingMissingOverviews(response, path: path, queryItems: []).results
    }

    /// Movies currently playing in theatres (region-aware).
    static func nowPlayingMovies(region: String = "IT") async throws -> [TMDBMovie] {
        let queryItems = [URLQueryItem(name: "region", value: region)]
        let response: TMDBMovieListResponse = try await request(path: "/movie/now_playing", queryItems: queryItems)
        return await fillingMissingOverviews(response, path: "/movie/now_playing", queryItems: queryItems).results
    }

    /// Upcoming cinema releases (region-aware), used for release-day notifications.
    static func upcomingMovies(region: String = "IT") async throws -> [TMDBMovie] {
        let queryItems = [URLQueryItem(name: "region", value: region)]
        let response: TMDBMovieListResponse = try await request(path: "/movie/upcoming", queryItems: queryItems)
        return response.results
    }

    /// Random high-quality movie for the "Sorprendimi" slot machine:
    /// popular titles rated 7+, excluding horror and already-watched ids.
    static func surpriseMovie(excluding excluded: Set<Int> = []) async throws -> TMDBMovie? {
        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "sort_by", value: "popularity.desc"),
            URLQueryItem(name: "vote_average.gte", value: "7"),
            URLQueryItem(name: "vote_count.gte", value: "1000"),
            URLQueryItem(name: "include_adult", value: "false"),
            URLQueryItem(name: "without_genres", value: String(TMDBGenre.horror)),
            URLQueryItem(name: "page", value: String(Int.random(in: 1...15)))
        ]
        let response: TMDBMovieListResponse = try await request(path: "/discover/movie", queryItems: queryItems)
        let filled = await fillingMissingOverviews(response, path: "/discover/movie", queryItems: queryItems)
        let fresh = filled.results.filter { !excluded.contains($0.id) }
        return fresh.randomElement() ?? filled.results.randomElement()
    }

    /// Free-text movie search, used when planning a movie on a diary day.
    static func searchMovies(query: String) async throws -> [TMDBMovie] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let queryItems = [
            URLQueryItem(name: "query", value: trimmed),
            URLQueryItem(name: "include_adult", value: "false")
        ]
        let response: TMDBMovieListResponse = try await request(path: "/search/movie", queryItems: queryItems)
        return response.results
    }

    /// Videos (trailers) only — lightweight call for quick access from result cards.
    /// Requests trailers in the user's language plus English as fallback.
    static func movieVideos(id: Int) async throws -> TMDBVideoList {
        let queryItems = [
            URLQueryItem(name: "include_video_language", value: videoLanguageParam)
        ]
        return try await request(path: "/movie/\(id)/videos", queryItems: queryItems)
    }

    /// Full movie detail with cast and videos in a single call.
    /// Falls back to the English overview when the localized one is missing.
    static func movieDetail(id: Int) async throws -> TMDBMovieDetail {
        let queryItems = [
            URLQueryItem(name: "append_to_response", value: "credits,videos,watch/providers"),
            URLQueryItem(name: "include_video_language", value: videoLanguageParam)
        ]
        let detail: TMDBMovieDetail = try await request(path: "/movie/\(id)", queryItems: queryItems)

        guard detail.overview.isEmpty, LocalizationManager.shared.language != .english else {
            return detail
        }
        if let english: TMDBMovieDetail = try? await request(
            path: "/movie/\(id)", queryItems: queryItems, languageOverride: "en-US"
        ), !english.overview.isEmpty {
            return detail.withOverview(english.overview)
        }
        return detail
    }

    /// When TMDB has no localized overview for some movies in a list,
    /// fetches the same page in English (one extra call at most) and fills
    /// only the missing overviews — no field is ever left empty needlessly.
    private static func fillingMissingOverviews(
        _ response: TMDBMovieListResponse,
        path: String,
        queryItems: [URLQueryItem]
    ) async -> TMDBMovieListResponse {
        guard LocalizationManager.shared.language != .english,
              response.results.contains(where: { $0.overview.isEmpty }) else {
            return response
        }
        guard let english: TMDBMovieListResponse = try? await request(
            path: path, queryItems: queryItems, languageOverride: "en-US"
        ) else { return response }

        let englishOverviews = Dictionary(
            english.results.map { ($0.id, $0.overview) },
            uniquingKeysWith: { first, _ in first }
        )
        let merged = response.results.map { movie -> TMDBMovie in
            guard movie.overview.isEmpty,
                  let fallback = englishOverviews[movie.id],
                  !fallback.isEmpty else { return movie }
            return movie.withOverview(fallback)
        }
        return TMDBMovieListResponse(
            page: response.page,
            results: merged,
            totalPages: response.totalPages,
            totalResults: response.totalResults
        )
    }

    // MARK: - Core request

    private static func request<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem],
        languageOverride: String? = nil
    ) async throws -> T {
        let apiKey = Config.EXPO_PUBLIC_TMDB_API_KEY
        guard !apiKey.isEmpty else { throw TMDBError.missingAPIKey }

        guard var components = URLComponents(string: baseURL + path) else {
            throw TMDBError.invalidURL
        }
        components.queryItems = queryItems + [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "language", value: languageOverride ?? language)
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
