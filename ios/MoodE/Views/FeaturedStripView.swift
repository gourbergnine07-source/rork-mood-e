//
//  FeaturedStripView.swift
//  MoodE
//

import SwiftUI

/// "In evidenza" strip at the top of Home: slim full-width rows for every
/// active editorial collection, so nothing hides behind horizontal scroll.
/// Tapping a row pushes the collection's movie list.
struct FeaturedStripView: View {
    private let collections: [FeaturedCollection] = FeaturedCalendar.activeCollections()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.amber)
                Text(L("home.featured.title"))
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Theme.ink)
            }
            .padding(.horizontal, 24)

            VStack(spacing: 8) {
                ForEach(collections) { collection in
                    NavigationLink(value: collection) {
                        FeaturedCardView(collection: collection)
                    }
                    .buttonStyle(PressableCardStyle())
                }
            }
            .padding(.horizontal, 24)
        }
    }
}

/// Slim full-width gradient row of the featured strip.
struct FeaturedCardView: View {
    let collection: FeaturedCollection

    var body: some View {
        HStack(spacing: 9) {
            Group {
                if EmojiSupport.isAvailable {
                    Text(collection.emoji)
                        .font(.system(size: 16))
                } else {
                    Image(systemName: collection.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 28, height: 28)
            .background(.white.opacity(0.22), in: .circle)

            Text(collection.title)
                .font(.footnote.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(collection.subtitle)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                .layoutPriority(-1)

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: collection.gradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .capsule
        )
        .overlay(
            Capsule()
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: (collection.gradient.first ?? .black).opacity(0.18), radius: 5, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(collection.title). \(collection.subtitle)")
    }
}

#Preview {
    NavigationStack {
        ZStack {
            Theme.background.ignoresSafeArea()
            FeaturedStripView()
        }
    }
}
