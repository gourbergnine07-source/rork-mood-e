//
//  WatchProvidersSection.swift
//  MoodE
//
//  Extracted from MovieDetailView to keep type-checking fast.
//

import SwiftUI

/// "Dove guardarlo": streaming, rent and buy providers for the user's
/// region, with the JustWatch attribution required by TMDB.
/// Tapping a provider opens the movie on that platform: Amazon/Apple go
/// through our affiliate links, everything else (Netflix, Disney+, ...)
/// opens the TMDB/JustWatch deep link for the title.
struct WatchProvidersSection: View {
    let region: TMDBWatchProviderRegion
    let title: String
    let year: String?

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("detail.watch"))
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.ink)

            Text(L("detail.watch.tap"))
                .font(.caption)
                .foregroundStyle(Theme.inkSoft.opacity(0.85))

            if let flatrate = region.flatrate, !flatrate.isEmpty {
                providerGroup(label: L("detail.watch.stream"), icon: "play.tv.fill", providers: flatrate)
            }
            if let rent = region.rent, !rent.isEmpty {
                providerGroup(label: L("detail.watch.rent"), icon: "arrow.down.circle", providers: rent)
            }
            if let buy = region.buy, !buy.isEmpty {
                providerGroup(label: L("detail.watch.buy"), icon: "bag", providers: buy)
            }

            if let link = region.linkURL {
                Link(destination: link) {
                    HStack(spacing: 5) {
                        Text(L("detail.watch.link"))
                            .font(.footnote.weight(.semibold))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(Theme.primary)
                }
            }

            Text(L("detail.watch.justwatch"))
                .font(.caption2)
                .foregroundStyle(Theme.inkSoft.opacity(0.7))
        }
    }

    private func providerGroup(label: String, icon: String, providers: [TMDBWatchProvider]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(label, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.inkSoft)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(providers) { provider in
                        ProviderLogo(provider: provider) {
                            openProvider(provider)
                        }
                    }
                }
            }
            .padding(.horizontal, -24)
            .contentMargins(.horizontal, 24)
        }
    }

    /// Provider logo tap: Amazon/Apple go through our affiliate links,
    /// every other platform opens the TMDB/JustWatch deep link.
    private func openProvider(_ provider: TMDBWatchProvider) {
        guard let destination = AffiliateLinks.providerDestination(
            for: provider,
            title: title,
            year: year,
            justWatchLink: region.linkURL
        ) else { return }

        switch destination.kind {
        case .affiliate:
            AnalyticsService.shared.log("affiliate_tap", meta: ["store": destination.store])
        case .justWatch:
            AnalyticsService.shared.log("provider_tap", meta: ["provider": provider.providerName])
        }
        openURL(destination.url)
    }
}

/// Rounded streaming service logo with its name below.
/// Tapping it opens the movie on that platform (affiliate or JustWatch).
struct ProviderLogo: View {
    let provider: TMDBWatchProvider
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            logoContent
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityLabel(provider.providerName)
        .accessibilityHint(L("detail.watch.tap"))
    }

    private var logoContent: some View {
        VStack(spacing: 6) {
            Color(Theme.surface)
                .frame(width: 54, height: 54)
                .overlay {
                    if let url = provider.logoURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .allowsHitTesting(false)
                            case .failure:
                                logoFallback
                            default:
                                ProgressView()
                                    .tint(Theme.primary)
                            }
                        }
                    } else {
                        logoFallback
                    }
                }
                .clipShape(.rect(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Theme.primary.opacity(0.12), lineWidth: 1)
                )

            Text(provider.providerName)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Theme.inkSoft)
                .lineLimit(1)
                .frame(width: 64)
        }
    }

    private var logoFallback: some View {
        Image(systemName: "play.rectangle")
            .font(.system(size: 20))
            .foregroundStyle(Theme.primary.opacity(0.4))
    }
}
