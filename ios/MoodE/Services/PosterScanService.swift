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

        // Best TMDB match per candidate, plus runner-up results kept aside
        // so the chooser can always offer 2-3 real alternatives.
        var movies: [TMDBMovie] = []
        var alternates: [TMDBMovie] = []
        for candidate in candidates.prefix(3) {
            guard let results = try? await TMDBService.searchMovies(query: candidate.title),
                  !results.isEmpty else { continue }
            let best = pickMatch(from: results, year: candidate.year)
            if !movies.contains(where: { $0.id == best.id }) {
                movies.append(best)
            }
            alternates.append(contentsOf: results.prefix(4).filter { $0.id != best.id })
        }
        for extra in alternates where movies.count < 3 {
            if !movies.contains(where: { $0.id == extra.id }) {
                movies.append(extra)
            }
        }
        guard !movies.isEmpty else { throw PosterScanError.notRecognized }

        // Direct navigation only when the model proposed a single,
        // high-confidence title. The padded chooser stays available behind
        // the detail page, so the user can go back and pick another match.
        let confident = candidates.count == 1 && (candidates.first?.isHighConfidence ?? false)
        return PosterScanOutcome(movies: movies, isConfident: confident)
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
        You identify movie posters. The photo may be blurry, tilted, partially cropped, taken at an angle, or a photo of a screen/monitor — do your best anyway using the artwork, typography, actors and any readable text.
        Reply ONLY with minified JSON, no markdown, in this exact shape:
        {"candidates":[{"title":"<movie title>","year":<release year or null>,"confidence":"high|medium|low"}]}
        Rules: 1 candidate with confidence "high" ONLY if you are absolutely certain; otherwise ALWAYS return 2-3 plausible candidates ordered from most to least likely. Use the movie's original or best-known international title so it can be found on TMDB. If the image is clearly not a movie poster, reply {"candidates":[]}.
        """

        let body: [String: Any] = [
            "model": "google/gemini-3-flash",
            "temperature": 0,
            "max_tokens": 2000,
            "reasoning_effort": "low",
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
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let snippet = String(data: data.prefix(300), encoding: .utf8) ?? ""
            print("PosterScan: HTTP \(status) — \(snippet)")
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

    /// Picks the best TMDB result for a candidate. Preference order:
    /// release year within ±1 of the model's guess, then the top search
    /// result (TMDB orders by relevance/popularity).
    private static func pickMatch(from results: [TMDBMovie], year: Int?) -> TMDBMovie {
        if let year {
            let byYear = results.first { movie in
                guard let movieYear = Int(movie.releaseYear ?? "") else { return false }
                return abs(movieYear - year) <= 1
            }
            if let byYear { return byYear }
        }
        return results[0]
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
