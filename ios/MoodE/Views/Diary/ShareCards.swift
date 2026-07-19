//
//  ShareCards.swift
//  MoodE
//

import SwiftUI
import UIKit

/// Rendered card image ready for the system share sheet.
struct ShareCardPayload: Identifiable {
    let id = UUID()
    let image: UIImage
    let title: String
}

/// Renders a SwiftUI card view into a high-resolution UIImage,
/// entirely on device (no backend involved).
enum ShareCardRenderer {
    static func render<Content: View>(_ content: Content) -> UIImage? {
        let renderer = ImageRenderer(content: content)
        renderer.scale = 3
        renderer.isOpaque = true
        return renderer.uiImage
    }
}

/// Bottom sheet with the generated card preview and a native ShareLink.
struct ShareCardSheet: View {
    let payload: ShareCardPayload

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Theme.inkSoft.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 10)

            Image(uiImage: payload.image)
                .resizable()
                .scaledToFit()
                .clipShape(.rect(cornerRadius: 18))
                .shadow(color: .black.opacity(0.25), radius: 14, y: 8)
                .frame(maxHeight: 400)

            ShareLink(
                item: Image(uiImage: payload.image),
                preview: SharePreview(payload.title, image: Image(uiImage: payload.image))
            ) {
                Label(L("memories.share"), systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Theme.primary, in: .rect(cornerRadius: 14))
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .presentationDetents([.height(540)])
    }
}

/// Story-friendly card of a single movie memory: poster, emoji rating,
/// comment and the Mood-E brand. Fixed size for deterministic rendering.
struct MemoryShareCardView: View {
    let memory: MovieMemory
    let poster: UIImage?

    private let cardBackground = LinearGradient(
        colors: [
            Color(red: 0.075, green: 0.086, blue: 0.157),
            Color(red: 0.211, green: 0.102, blue: 0.184)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    private let cream = Color(red: 0.949, green: 0.918, blue: 0.890)

    var body: some View {
        VStack(spacing: 14) {
            Text("🎬 Mood-E")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(cream.opacity(0.85))
                .kerning(1.5)

            posterView

            Text(memory.title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(cream)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(LF("card.watchedOn", formattedDate))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(cream.opacity(0.6))

            Text(memory.ratingEmoji)
                .font(.system(size: 44))

            if let comment = memory.comment {
                Text("\u{201C}\(comment)\u{201D}")
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .italic()
                    .foregroundStyle(cream.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(width: 350, height: 600)
        .background(cardBackground)
    }

    @ViewBuilder
    private var posterView: some View {
        if let poster {
            Image(uiImage: poster)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 210, height: 315)
                .clipShape(.rect(cornerRadius: 16))
                .shadow(color: .black.opacity(0.45), radius: 16, y: 10)
        } else {
            RoundedRectangle(cornerRadius: 16)
                .fill(cream.opacity(0.10))
                .frame(width: 210, height: 315)
                .overlay {
                    Text("🎬").font(.system(size: 52))
                }
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = LocalizationManager.shared.locale
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: memory.watchedDate)
    }
}

/// Wrapped-style shareable card summarising a month of movies.
struct MonthlyRecapShareCardView: View {
    let recap: MonthlyRecap
    let monthTitle: String

    private let cardBackground = LinearGradient(
        colors: [
            Color(red: 0.075, green: 0.086, blue: 0.157),
            Color(red: 0.278, green: 0.129, blue: 0.098)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    private let cream = Color(red: 0.949, green: 0.918, blue: 0.890)
    private let gold = Color(red: 0.980, green: 0.749, blue: 0.439)

    var body: some View {
        VStack(spacing: 18) {
            Text("🎬 Mood-E")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(cream.opacity(0.85))
                .kerning(1.5)

            Text(L("recap.month.title"))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(cream)

            Text(monthTitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(gold)
                .textCase(.uppercase)
                .kerning(2)

            Text("\(recap.watchedCount)")
                .font(.system(size: 88, weight: .black, design: .rounded))
                .foregroundStyle(gold)

            Text(LF("recap.month.watched", recap.watchedCount))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(cream)
                .padding(.top, -14)

            VStack(spacing: 10) {
                if let mood = recap.topMood {
                    statRow(LF("recap.month.mood", mood.title, mood.emoji))
                }
                if let genre = recap.topGenreName {
                    statRow(LF("recap.month.genre", genre))
                }
                if let favorite = recap.favorite {
                    statRow(LF("recap.month.favorite", favorite.title) + " \(favorite.ratingEmoji)")
                }
            }
            .padding(.top, 4)

            Spacer(minLength: 0)
        }
        .padding(28)
        .frame(width: 350, height: 600)
        .background(cardBackground)
    }

    private func statRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundStyle(cream.opacity(0.92))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(cream.opacity(0.08), in: .rect(cornerRadius: 12))
    }
}
