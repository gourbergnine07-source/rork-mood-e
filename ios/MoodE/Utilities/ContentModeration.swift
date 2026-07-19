//
//  ContentModeration.swift
//  MoodE
//

import Foundation

/// Client-side profanity filter for community content (IT/EN/ES/FR).
/// Mirrors the server-side filter: the backend applies the same rules,
/// this local pass just gives instant feedback before sending.
nonisolated enum ContentModeration {
    private static let blockedWords: Set<String> = {
        let words = [
            // Italian
            "cazzo", "merda", "stronzo", "stronza", "vaffanculo", "puttana", "troia",
            "coglione", "bastardo", "porca", "porco", "negro", "frocio", "mignotta",
            "zoccola", "pompino", "culo",
            // English
            "fuck", "shit", "bitch", "asshole", "bastard", "cunt", "dick", "faggot",
            "nigger", "whore", "slut", "retard",
            // Spanish
            "mierda", "puta", "puto", "gilipollas", "cabron", "joder",
            "pendejo", "maricon", "cono", "polla", "zorra",
            // French
            "putain", "salope", "connard", "connasse", "encule",
            "pute", "batard", "nique", "pd"
        ]
        return Set(words.map(normalize))
    }()

    private static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .lowercased()
    }

    /// True when the text contains no blocked word.
    static func isClean(_ text: String) -> Bool {
        let separators = CharacterSet.alphanumerics.inverted
        let words = normalize(text).components(separatedBy: separators)
        return !words.contains { $0.count > 1 && blockedWords.contains($0) }
    }
}
