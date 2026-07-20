//
//  FeaturedStripView.swift
//  MoodE
//

import SwiftUI

/// "In evidenza" strip at the top of Home: horizontally scrollable
/// editorial collections driven by the seasonal theme calendar.
/// Tapping a card pushes the collection's movie list.
struct FeaturedStripView: View {
    private let collections: [FeaturedCollection] = FeaturedCalendar.activeCollections()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.amber)
                Text(L("home.featured.title"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.ink)
            }
            .padding(.horizontal, 24)

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(collections) { collection in
                        NavigationLink(value: collection) {
                            FeaturedCardView(collection: collection)
                        }
                        .buttonStyle(PressableCardStyle())
                    }
                }
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, 24)
        }
    }
}

/// Single gradient card of the featured strip.
struct FeaturedCardView: View {
    let collection: FeaturedCollection

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: collection.gradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Oversized ghost emoji adds depth without extra assets.
            if EmojiSupport.isAvailable {
                Text(collection.emoji)
                    .font(.system(size: 64))
                    .opacity(0.25)
                    .rotationEffect(.degrees(-12))
                    .offset(x: 158, y: -26)
            } else {
                Image(systemName: collection.icon)
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(.white.opacity(0.18))
                    .rotationEffect(.degrees(-12))
                    .offset(x: 158, y: -26)
            }

            VStack(alignment: .leading, spacing: 3) {
                if EmojiSupport.isAvailable {
                    Text(collection.emoji)
                        .font(.system(size: 22))
                } else {
                    Image(systemName: collection.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text(collection.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(collection.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(12)
        }
        .frame(width: 230, height: 116)
        .clipShape(.rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: (collection.gradient.first ?? .black).opacity(0.25), radius: 8, y: 4)
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
