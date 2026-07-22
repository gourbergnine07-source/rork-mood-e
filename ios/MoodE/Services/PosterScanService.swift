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
    let confidence: String?

    var isHighConfidence: Bool { confidence?.lowercased() == "high" }
}

/// Errors surfaced by the poster recognition flow.
nonisolated enum PosterScanError: LocalizedError {
    case missingKey
    case imageTooLarge
    case badResponse
    case notRecognized

    var errorDescription: String? {
        switch self {
        case .notRecognized: return LN("scan.failed.title")
        default: return LN("error.generic")
        }
    }
}

/// Recognition result: real TMDB movies matched from the model candidates.
struct PosterScanOutcome {
    let movies: [TMDBMovie]
    /// True when there is exactly one high-confidence match: the UI opens
    /// the detail page directly without asking the user to choose.
    let isConfident: Bool
}

/// "Scansiona un poster": sends the photo to the Rork Toolkit AI proxy
/// (Gemini 3.6 Flash, vision) to extract title/year candidates, then
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

        var movies: [TMDBMovie] = []
        for candidate in candidates.prefix(3) {
            guard let match = await bestMatch(for: candidate) else { continue }
            if !movies.contains(where: { $0.id == match.id }) {
                movies.append(match)
            }
        }
        guard !movies.isEmpty else { throw PosterScanError.notRecognized }

        let confident = candidates.count == 1 && (candidates.first?.isHighConfidence ?? false)
        return PosterScanOutcome(movies: movies, isConfident: confident && movies.count == 1)
    }

    // MARK: - Vision call

    private static func recognize(base64: String) async throws -> [PosterCandidate] {
        let toolkitURL = Config.EXPO_PUBLIC_TOOLKIT_URL
        let secret = Config.EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY
        guard !toolkitURL.isEmpty, !secret.isEmpty,
              let url = URL(string: "\(toolkitURL)/v2/vercel/v1/chat/completions") else {
            throw PosterScanError.missingKey
        }

        let prompt = """
        You identify movie posters. Look at the image and identify the movie.
        Reply ONLY with minified JSON, no markdown, in this exact shape:
        {"candidates":[{"title":"<movie title>","year":<release year or null>,"confidence":"high|medium|low"}]}
        Rules: at most 3 candidates, most likely first. Use the movie's original or best-known international title so it can be found on TMDB. If the image is not a movie poster or you cannot identify it, reply {"candidates":[]}.
        """

        let body: [String: Any] = [
            "model": "google/gemini-3.6-flash",
            "temperature": 0,
            "max_tokens": 300,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": prompt],
                        [
                            "type": "image_url",
                            "image_url": ["url": "data:image/jpeg;base64,\(base64)"]
                        ]
                    ]
                ]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 45

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw PosterScanError.badResponse
        }

        let chat = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = chat.choices.first?.message.content else {
            throw PosterScanError.badResponse
        }
        return parseCandidates(from: content)
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

    /// Turns a title/year candidate into a real TMDB movie. Preference
    /// order: release year within ±1 of the model's guess, then the top
    /// search result (TMDB orders by relevance/popularity).
    private static func bestMatch(for candidate: PosterCandidate) async -> TMDBMovie? {
        guard let results = try? await TMDBService.searchMovies(query: candidate.title),
              !results.isEmpty else { return nil }

        if let year = candidate.year {
            let byYear = results.first { movie in
                guard let movieYear = Int(movie.releaseYear ?? "") else { return false }
                return abs(movieYear - year) <= 1
            }
            if let byYear { return byYear }
        }
        return results.first
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
