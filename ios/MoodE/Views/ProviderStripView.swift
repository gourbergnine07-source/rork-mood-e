//
//  ProviderStripView.swift
//  MoodE
//

import SwiftUI

/// Compact strip of streaming-platform logos shown under a movie card,
/// so users see at a glance where a title is available. Loads lazily
/// through `WatchProviderCache` and stays hidden when nothing is found.
struct ProviderStripView: View {
    let movieId: Int
    var tint: Color = Theme.primary

    @State private var providers: [TMDBWatchProvider] = []

    var body: some View {
        Group {
            if !providers.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "play.tv.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(tint.opacity(0.75))

                    ForEach(providers.prefix(3)) { provider in
                        providerLogo(provider)
                    }

                    if providers.count > 3 {
                        Text("+\(providers.count - 3)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                .transition(.opacity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "\(L("card.availableOn")) \(providers.map(\.providerName).joined(separator: ", "))"
                )
            }
        }
        .task(id: movieId) {
            let fetched = await WatchProviderCache.shared.providers(for: movieId)
            withAnimation(.easeIn(duration: 0.2)) {
                providers = fetched
            }
        }
    }

    private func providerLogo(_ provider: TMDBWatchProvider) -> some View {
        Color(Theme.surface)
            .frame(width: 18, height: 18)
            .overlay {
                if let url = provider.logoURL {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .allowsHitTesting(false)
                        } else {
                            logoFallback
                        }
                    }
                } else {
                    logoFallback
                }
            }
            .clipShape(.rect(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Theme.ink.opacity(0.08), lineWidth: 0.5)
            )
    }

    private var logoFallback: some View {
        Image(systemName: "play.rectangle")
            .font(.system(size: 9))
            .foregroundStyle(tint.opacity(0.4))
    }
}
