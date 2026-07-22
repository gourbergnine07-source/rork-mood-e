//
//  EmojiSupport.swift
//  MoodE
//

import UIKit

/// Detects whether the system can actually render color emoji.
/// Some stripped-down simulators ship without the Apple Color Emoji font,
/// so every emoji becomes a "?" tofu glyph; views use this flag to fall
/// back to tinted SF Symbols. Real devices always return true.
///
/// Font-name checks are unreliable (the simulator can still report an
/// emoji font that fails to draw), so the emoji is rendered into a tiny
/// bitmap: real color emoji produce colored pixels, the tofu "?" is
/// pure monochrome.
enum EmojiSupport {
    static let isAvailable: Bool = {
        let side = 16
        var pixels = [UInt8](repeating: 0, count: side * side * 4)

        guard let context = CGContext(
            data: &pixels,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return false }

        UIGraphicsPushContext(context)
        ("\u{1F642}" as NSString).draw(
            in: CGRect(x: 0, y: 0, width: side, height: side),
            withAttributes: [.font: UIFont.systemFont(ofSize: 13)]
        )
        UIGraphicsPopContext()

        var index = 0
        while index + 3 < pixels.count {
            let red = Int(pixels[index])
            let green = Int(pixels[index + 1])
            let blue = Int(pixels[index + 2])
            let alpha = Int(pixels[index + 3])
            let isColored = abs(red - green) > 8 || abs(green - blue) > 8 || abs(red - blue) > 8
            if alpha > 0 && isColored { return true }
            index += 4
        }
        return false
    }()
}
