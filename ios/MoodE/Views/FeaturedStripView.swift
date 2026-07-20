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

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
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

/// Compact gradient chip of the featured strip.
struct FeaturedCardView: View {
    let collection: FeaturedCollection

    var body: some View {
        HStack(spacing: 9) {
            Group {
                if EmojiSupport.isAvailable {
                    Text(collection.emoji)
                        .font(.system(size: 18))
                } else {
                    Image(systemName: collection.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 32, height: 32)
            .background(.white.opacity(0.22), in: .circle)

            VStack(alignment: .leading, spacing: 1) {
                Text(collection.title)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(collection.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .padding(.vertical, 8)
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
        .shadow(color: (collection.gradient.first ?? .black).opacity(0.2), radius: 6, y: 3)
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
