//
//  MoodTextAnalyzer.swift
//  MoodE
//

import Foundation

/// Sends the user's free-form "how I feel" text to a small, fast language
/// model through the app's backend (POST /ai/mood — the model, prompt and
/// API key live server-side) and maps it to the closest of the 12 moods and,
/// when clear enough, the closest of the 10 viewing goals. The raw text is
/// used only for this single call and is never stored or logged.
nonisolated enum MoodTextAnalyzerError: Error {
    /// Daily per-device analysis limit reached (HTTP 429).
    case limitReached
}

final class MoodTextAnalyzer {
    static let shared = MoodTextAnalyzer()
    private init() {}

    struct Interpretation {
        let mood: Mood
        let goal: ViewingGoal?
    }

    private nonisolated struct ChatResponse: Codable {
        struct Choice: Codable { let message: Message }
        struct Message: Codable { let content: String? }
        let choices: [Choice]
    }

    private nonisolated struct ParsedResult: Codable {
        let mood: String
        let goal: String?
    }

    func analyze(_ text: String) async throws -> Interpretation {
        guard !Config.EXPO_PUBLIC_RORK_FUNCTIONS_URL.isEmpty,
              let url = URL(string: Config.EXPO_PUBLIC_RORK_FUNCTIONS_URL + "/ai/mood") else {
            throw URLError(.badURL)
        }

        // Max 500 Unicode scalars: the server counts code points the same
        // way, so emoji-heavy text never gets rejected.
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let limited = String(String.UnicodeScalarView(trimmed.unicodeScalars.prefix(500)))
        let body: [String: String] = [
            "deviceId": CommunityService.shared.deviceId,
            "text": limited
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        if http.statusCode == 429 { throw MoodTextAnalyzerError.limitReached }
        guard (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content,
              let parsed = Self.extractJSON(from: content),
              let mood = Mood(rawValue: parsed.mood.lowercased()) else {
            throw URLError(.cannotParseResponse)
        }

        let goal = parsed.goal.flatMap { ViewingGoal(rawValue: $0.lowercased()) }
        return Interpretation(mood: mood, goal: goal)
    }

    /// Extracts the JSON object from the model reply, tolerating markdown
    /// fences or stray text around it.
    private nonisolated static func extractJSON(from content: String) -> ParsedResult? {
        guard let start = content.firstIndex(of: "{"),
              let end = content.lastIndex(of: "}"), start < end else { return nil }
        let json = String(content[start...end])
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ParsedResult.self, from: data)
    }
}
