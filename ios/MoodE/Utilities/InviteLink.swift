//
//  InviteLink.swift
//  MoodE
//

import Foundation

/// Builds the personal invite link shared from "Invite friends".
/// The link opens a localized landing page showing the friend code,
/// with an App Store download button and a `moode://invite/<code>`
/// deep link back into the app.
enum InviteLink {
    /// Personal invite URL for a friend code, or nil when the functions
    /// backend URL is not configured.
    static func url(code: String) -> URL? {
        let base = Config.EXPO_PUBLIC_RORK_FUNCTIONS_URL
        guard !base.isEmpty, var components = URLComponents(string: base) else { return nil }
        components.path = "/invite"
        components.queryItems = [
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "l", value: LocalizationManager.shared.language.rawValue)
        ]
        return components.url
    }

    /// Ready-to-share message: includes the link when available,
    /// falls back to the code-only text otherwise.
    static func shareMessage(code: String) -> String {
        if let url = url(code: code) {
            return LF("invite.share.text", code, url.absoluteString)
        }
        return LF("friends.share.text", code)
    }
}
