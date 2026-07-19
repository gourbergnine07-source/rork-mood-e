//
//  EmojiSupport.swift
//  MoodE
//

import UIKit
import CoreText

/// Detects whether the system can actually render color emoji.
/// Some stripped-down simulators ship without the Apple Color Emoji font,
/// so every emoji becomes a "?" tofu glyph; views use this flag to fall
/// back to tinted SF Symbols. Real devices always return true.
enum EmojiSupport {
    static let isAvailable: Bool = {
        if UIFont(name: "AppleColorEmoji", size: 17) != nil { return true }

        // Fallback check: ask CoreText which font would draw an emoji.
        let sample = "🙂" as CFString
        let base = CTFontCreateWithName("Helvetica" as CFString, 17, nil)
        let resolved = CTFontCreateForString(
            base,
            sample,
            CFRange(location: 0, length: CFStringGetLength(sample))
        )
        let name = (CTFontCopyPostScriptName(resolved) as String).lowercased()
        return name.contains("emoji")
    }()
}
