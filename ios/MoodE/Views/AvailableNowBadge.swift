//
//  AvailableNowBadge.swift
//  MoodE
//

import SwiftUI

/// Small "Available now" badge overlaid on a movie poster when the film
/// is included in one of the streaming services the user marked as
/// active in Settings. Stays hidden otherwise. `compact` shows an
/// icon-only version for tiny posters.
struct AvailableNowBadge: View {
    let movieId: Int
    var compact: Bool = false

    @State private var flatrate: [TMDBWatchProvider] = []

    private var services: StreamingServicesStore { .shared }

    private var isAvailable: Bool {
        services.matchesAny(of: flatrate)
    }

    var body: some View {
        Group {
            if isAvailable {
                badge
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
        }
        .task(id: movieId) {
            guard services.hasSelection else { return }
            let fetched = await WatchProviderCache.shared.flatrateProviders(for: movieId)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                flatrate = fetched
            }
        }
    }

    @ViewBuilder
    private var badge: some View {
        if compact {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white, Theme.seenGreen)
                .background(.white.opacity(0.9), in: .circle)
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                .accessibilityLabel(L("card.availableNow"))
        } else {
            HStack(spacing: 3) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 8, weight: .bold))
                Text(L("card.availableNow"))
                    .font(.system(size: 9, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Theme.seenGreen.opacity(0.94), in: .capsule)
            .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
            .accessibilityLabel(L("card.availableNow"))
        }
    }
}
