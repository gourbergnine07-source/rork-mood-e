//
//  MoodTextAnalyzer.swift
//  MoodE
//

import Foundation

/// Sends the user's free-form "how I feel" text to a small, fast language
/// model (google/gemini-3.1-flash-lite via the Rork Toolkit proxy) and maps
/// it to the closest of the 12 moods and, when clear enough, the closest of
/// the 10 viewing goals. The raw text is used only for this single call and
/// is never stored or logged.
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
        guard let url = URL(string: Config.EXPO_PUBLIC_TOOLKIT_URL + "/v2/vercel/v1/chat/completions") else {
            throw URLError(.badURL)
        }

        let moods = Mood.allCases.map(\.rawValue).joined(separator: ", ")
        let goals = ViewingGoal.allCases.map(\.rawValue).joined(separator: ", ")
        let system = """
        You classify how a person feels based on a short free-form text \
        (any language) about their day or mood, to recommend a movie.

        Pick exactly one mood id from this list: \(moods).
        If the text also implies what they want from the movie tonight, pick \
        one goal id from this list: \(goals). Otherwise use null.

        Reply with ONLY a minified JSON object, no markdown, no explanation:
        {"mood":"<mood id>","goal":"<goal id or null>"}
        """

        let systemMessage: [String: String] = ["role": "system", "content": system]
        let userMessage: [String: String] = ["role": "user", "content": String(text.prefix(500))]
        var body: [String: Any] = [:]
        body["model"] = "google/gemini-3.1-flash-lite"
        body["temperature"] = 0
        body["max_tokens"] = 2000
        body["messages"] = [systemMessage, userMessage]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(
            "Bearer \(Config.EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY)",
            forHTTPHeaderField: "Authorization"
        )
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
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
