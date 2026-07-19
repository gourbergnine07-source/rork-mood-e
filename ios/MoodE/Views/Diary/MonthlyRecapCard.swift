//
//  MonthlyRecapCard.swift
//  MoodE
//

import SwiftUI

/// Wrapped-style monthly recap card shown in the diary when at least
/// 8 movies were watched in the current month. Shareable as an image
/// generated locally on device.
struct MonthlyRecapCard: View {
    let recap: MonthlyRecap
    let monthTitle: String

    @State private var sharePayload: ShareCardPayload?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(L("recap.month.title"), systemImage: "film.stack")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.rose)
                Spacer()
                Button(action: share) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.rose)
                        .frame(width: 28, height: 28)
                        .background(Theme.rose.opacity(0.12), in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L("memories.share"))
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(recap.watchedCount)")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.rose)
                    .contentTransition(.numericText())
                Text(LF("recap.month.watched", recap.watchedCount))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.ink)
            }

            VStack(alignment: .leading, spacing: 4) {
                if let mood = recap.topMood {
                    Text(LF("recap.month.mood", mood.title, mood.emoji))
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
                if let genre = recap.topGenreName {
                    Text(LF("recap.month.genre", genre))
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
                if let favorite = recap.favorite {
                    Text(LF("recap.month.favorite", favorite.title) + " \(favorite.ratingEmoji)")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                        .lineLimit(2)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.rose.opacity(0.10), in: .rect(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.rose.opacity(0.35), lineWidth: 1)
        )
        .sheet(item: $sharePayload) { payload in
            ShareCardSheet(payload: payload)
        }
    }

    /// Renders the Wrapped-style card on device and opens the share preview.
    private func share() {
        let card = MonthlyRecapShareCardView(recap: recap, monthTitle: monthTitle)
        if let image = ShareCardRenderer.render(card) {
            sharePayload = ShareCardPayload(image: image, title: L("recap.month.title"))
        }
    }
}
