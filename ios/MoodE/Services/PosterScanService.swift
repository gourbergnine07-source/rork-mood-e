//
//  PosterScanService.swift
//  MoodE
//

import Foundation
import UIKit

/// One movie hypothesis extracted from the poster photo by the vision model.
nonisolated struct PosterCandidate: Codable {
    let title: String
    let year: Int?
    let type: String?
    let confidence: String?

    var isHighConfidence: Bool { confidence?.lowercased() == "high" }
    var isTVSeries: Bool { type?.lowercased() == "tv" }
}

/// Errors surfaced by the poster recognition flow.
nonisolated enum PosterScanError: LocalizedError {
    case missingKey
    /// Daily per-device scan limit reached (HTTP 429).
    case limitReached
    case imageTooLarge
    case badResponse
    case notRecognized
    /// The poster belongs to a TV series (associated value: series title).
    case tvSeries(String)
    /// The AI recognized a title, but TMDB has no matching movie.
    case notFoundOnTMDB(String)

    var errorDescription: String? {
        switch self {
        case .notRecognized: return LN("scan.failed.title")
        case .tvSeries: return LN("scan.tv.title")
        case .notFoundOnTMDB: return LN("scan.notfound.title")
        default: return LN("error.generic")
        }
    }
}

/// Recognition result: real TMDB movies matched from the model candidates.
struct PosterScanOutcome {
    let movies: [TMDBMovie]
    /// True only when the model was certain AND the TMDB match is solid
    /// (same title, well-known movie): the UI opens the detail directly.
    let isConfident: Bool
    /// Set when the poster looks like a TV series: the chooser shows an
    /// informative banner with the series name.
    let tvSeriesTitle: String?
}

/// "Scansiona un poster": sends the photo to the app's backend (POST
/// /ai/poster — vision model, prompt and API key live server-side) to extract title/year candidates, then
/// matches each candidate against TMDB so only real movies are shown.
/// Privacy: the photo is transmitted only for this one analysis, is never
/// stored by the app or linked to personal data, and is discarded after
/// processing.
enum PosterScanService {

    /// Identifies the movie(s) on a poster photo.
    static func identify(image: UIImage) async throws -> PosterScanOutcome {
        guard let base64 = preparedBase64(from: image) else {
            throw PosterScanError.imageTooLarge
        }

        let candidates = try await recognize(base64: base64)
        guard !candidates.isEmpty else { throw PosterScanError.notRecognized }

        // TV series are recognized but not matched against the movie DB:
        // searching a series title on /search/movie is exactly what returns
        // obscure homonym shorts instead of the real thing.
        let tvTitle = candidates.first(where: { $0.isTVSeries })?.title
        let movieCandidates = candidates.filter { !$0.isTVSeries }

        // Best TMDB match per candidate (ranked by title similarity +
        // popularity + year), plus runner-ups so the chooser always offers
        // 2-3 real alternatives.
        var movies: [TMDBMovie] = []
        var alternates: [TMDBMovie] = []
        var firstMatchIsSolid = false
        for (index, candidate) in movieCandidates.prefix(3).enumerated() {
            guard let results = try? await TMDBService.searchMovies(query: candidate.title),
                  !results.isEmpty else { continue }
            let ranked = results
                .map { (movie: $0, score: matchScore($0, candidate: candidate)) }
                .sorted { $0.score > $1.score }
            let best = ranked[0].movie
            if index == 0 {
                firstMatchIsSolid = normalized(best.title) == normalized(candidate.title)
                    && best.voteCount >= 200
            }
            if !movies.contains(where: { $0.id == best.id }) {
                movies.append(best)
            }
            alternates.append(contentsOf: ranked.dropFirst().prefix(4)
                .map(\.movie)
                .filter { $0.posterPath != nil || $0.voteCount >= 5 })
        }
        for extra in alternates where movies.count < 4 {
            if !movies.contains(where: { $0.id == extra.id }) {
                movies.append(extra)
            }
        }
        guard !movies.isEmpty else {
            if let tvTitle { throw PosterScanError.tvSeries(tvTitle) }
            // The model DID read a title, but the movie database has no
            // match: tell the user explicitly instead of a generic failure.
            if let recognized = movieCandidates.first?.title {
                throw PosterScanError.notFoundOnTMDB(recognized)
            }
            throw PosterScanError.notRecognized
        }

        // Direct navigation only when the model proposed a single
        // high-confidence movie AND TMDB agrees with a well-known exact
        // title match; otherwise the user always picks from the chooser.
        let confident = tvTitle == nil
            && movieCandidates.count == 1
            && (movieCandidates.first?.isHighConfidence ?? false)
            && firstMatchIsSolid
        return PosterScanOutcome(movies: movies, isConfident: confident, tvSeriesTitle: tvTitle)
    }

    // MARK: - Vision call

    private static func recognize(base64: String) async throws -> [PosterCandidate] {
        let functionsURL = Config.EXPO_PUBLIC_RORK_FUNCTIONS_URL
        guard !functionsURL.isEmpty,
              let url = URL(string: "\(functionsURL)/ai/poster") else {
            throw PosterScanError.missingKey
        }

        let body: [String: String] = [
            "deviceId": CommunityService.shared.deviceId,
            "image": base64
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 45

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw PosterScanError.badResponse
        }
        if http.statusCode == 429 { throw PosterScanError.limitReached }
        guard (200...299).contains(http.statusCode) else {
            print("PosterScan: HTTP \(http.statusCode)")
            throw PosterScanError.badResponse
        }

        let chat = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = chat.choices.first?.message.content, !content.isEmpty else {
            print("PosterScan: empty model content")
            throw PosterScanError.badResponse
        }
        let candidates = parseCandidates(from: content)
        if candidates.isEmpty {
            print("PosterScan: no candidates parsed from: \(content.prefix(200))")
        }
        return candidates
    }

    /// Extracts the JSON object from the model output (tolerates fences).
    private static func parseCandidates(from content: String) -> [PosterCandidate] {
        guard let start = content.firstIndex(of: "{"),
              let end = content.lastIndex(of: "}") else { return [] }
        let json = String(content[start...end])
        guard let data = json.data(using: .utf8),
              let payload = try? JSONDecoder().decode(CandidatePayload.self, from: data) else {
            return []
        }
        return payload.candidates.filter { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    // MARK: - TMDB matching

    /// Ranks a TMDB result against a model candidate. Combines title
    /// similarity, popularity (vote count, log scale) and year proximity so
    /// obscure homonyms (e.g. short films sharing a famous title) never
    /// outrank the well-known movie the user actually photographed.
    private static func matchScore(_ movie: TMDBMovie, candidate: PosterCandidate) -> Double {
        let movieTitle = normalized(movie.title)
        let candidateTitle = normalized(candidate.title)
        var score = 0.0

        if movieTitle == candidateTitle {
            score += 60
        } else if movieTitle.contains(candidateTitle) || candidateTitle.contains(movieTitle) {
            score += 30
        }

        // 0 votes → 0 pts, 100 votes → 20 pts, 1000+ votes → 30 pts (cap).
        score += min(30, log10(Double(max(movie.voteCount, 1))) * 10)

        if let year = candidate.year, let movieYear = Int(movie.releaseYear ?? "") {
            switch abs(movieYear - year) {
            case 0: score += 15
            case 1: score += 8
            default: break
            }
        }

        if movie.posterPath == nil { score -= 20 }
        return score
    }

    /// Case/diacritic/punctuation-insensitive form used for title equality.
    private static func normalized(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US"))
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    // MARK: - Image preparation

    /// Re-encodes the photo against a byte budget (proxy body limit):
    /// walks a resize/quality ladder and stops at the first fit.
    private static func preparedBase64(from image: UIImage) -> String? {
        let steps: [(maxEdge: CGFloat, quality: CGFloat)] = [
            (1280, 0.82), (1024, 0.78), (832, 0.74), (640, 0.70), (512, 0.65)
        ]
        let budget = 2_500_000

        for step in steps {
            let resized = resize(image, maxEdge: step.maxEdge)
            if let data = resized.jpegData(compressionQuality: step.quality),
               data.count <= budget {
                return data.base64EncodedString()
            }
        }
        return nil
    }

    private static func resize(_ image: UIImage, maxEdge: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxEdge, longest > 0 else { return image }
        let scale = maxEdge / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

// MARK: - Wire types

nonisolated private struct CandidatePayload: Codable {
    let candidates: [PosterCandidate]
}

nonisolated private struct ChatResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let content: String?
        }
        let message: Message
    }
    let choices: [Choice]
}
