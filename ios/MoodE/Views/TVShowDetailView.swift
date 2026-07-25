//
//  TVShowDetailView.swift
//  MoodE
//

import SwiftUI

/// Detail screen for a TV show: poster, seasons/episodes, next episode on
/// air, official trailer, streaming availability and main cast — the TV
/// twin of `MovieDetailView`.
struct TVShowDetailView: View {
    let show: TMDBTVShow

    @State private var viewModel = TVShowDetailViewModel()
    @State private var trailerToPlay: TMDBVideo?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            switch viewModel.state {
            case .loading:
                loadingView
            case .failed(let message):
                errorView(message)
            case .unavailable:
                unavailableView
            case .loaded(let detail):
                detailContent(detail)
            }
        }
        .navigationTitle(show.name)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: show.shareMessage, subject: Text(show.name)) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                }
                .accessibilityLabel(LF("share.a11y", show.name))
                .simultaneousGesture(TapGesture().onEnded {
                    AnalyticsService.shared.log("tv_shared", meta: ["id": String(show.id)])
                })
            }
        }
        .tint(Theme.primary)
        .task {
            await viewModel.load(showID: show.id)
        }
        .onChange(of: LocalizationManager.shared.language) { _, _ in
            Task { await viewModel.load(showID: show.id) }
        }
        .sheet(item: $trailerToPlay) { trailer in
            TrailerPlayerSheet(trailer: trailer, movieTitle: show.name)
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(Theme.primary)
            Text(L("detail.loading"))
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(Theme.primary)
            Text(L("common.oops"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
            Button {
                Task { await viewModel.load(showID: show.id) }
            } label: {
                Label(L("common.retry"), systemImage: "arrow.clockwise")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Theme.primary, in: .capsule)
            }
        }
        .padding(.horizontal, 32)
    }

    private var unavailableView: some View {
        VStack(spacing: 18) {
            Image(systemName: "tv")
                .font(.system(size: 40))
                .foregroundStyle(Theme.inkSoft)
            Text(L("detail.gone.title"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text(L("detail.gone.msg"))
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
            Button {
                dismiss()
            } label: {
                Label(L("detail.gone.home"), systemImage: "house.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Theme.primary, in: .capsule)
            }
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Content

    private func detailContent(_ detail: TMDBTVShowDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                posterHeader(detail)

                VStack(alignment: .leading, spacing: 20) {
                    titleBlock(detail)

                    if let next = detail.nextEpisodeToAir,
                       let formatted = next.formattedNextAiring {
                        nextEpisodeCard(next, formatted: formatted)
                    }

                    if let trailer = detail.trailer {
                        watchTrailerButton(trailer)
                    }

                    followSection

                    if !detail.genres.isEmpty {
                        genreChips(detail.genres)
                    }

                    if let watchRegion = detail.watchProviders?.bestRegion {
                        WatchProvidersSection(
                            region: watchRegion,
                            title: detail.name,
                            year: detail.firstAirYear
                        )
                    }

                    if !detail.overview.isEmpty {
                        overviewSection(detail.overview)
                    }

                    if !detail.mainCast.isEmpty {
                        castSection(detail.mainCast)
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
    }

    private func posterHeader(_ detail: TMDBTVShowDetail) -> some View {
        Color(Theme.surface)
            .frame(height: 420)
            .overlay {
                if let url = detail.posterURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .allowsHitTesting(false)
                        case .failure:
                            posterFallback
                        default:
                            ProgressView()
                                .tint(Theme.primary)
                        }
                    }
                } else {
                    posterFallback
                }
            }
            .clipped()
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [.clear, Theme.background.opacity(0.9)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .frame(height: 120)
                .allowsHitTesting(false)
            }
            .overlay {
                if let trailer = detail.trailer {
                    posterPlayButton(trailer)
                }
            }
    }

    private func posterPlayButton(_ trailer: TMDBVideo) -> some View {
        Button {
            trailerToPlay = trailer
        } label: {
            ZStack {
                Circle()
                    .fill(.black.opacity(0.45))
                    .frame(width: 72, height: 72)
                    .background(.ultraThinMaterial, in: .circle)

                Image(systemName: "play.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(x: 2)
            }
            .overlay(
                Circle().stroke(.white.opacity(0.6), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityLabel(L("trailer.watchLong"))
    }

    private var posterFallback: some View {
        Image(systemName: "tv")
            .font(.system(size: 48))
            .foregroundStyle(Theme.primary.opacity(0.4))
    }

    private func titleBlock(_ detail: TMDBTVShowDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(detail.name)
                .font(.title.weight(.bold))
                .foregroundStyle(Theme.ink)

            HStack(spacing: 10) {
                if let year = detail.firstAirYear {
                    metaBadge(icon: "calendar", text: year)
                }
                if let seasons = detail.numberOfSeasons, seasons > 0 {
                    metaBadge(icon: "square.stack", text: seasonsText(seasons))
                }
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.amber)
                    Text(LocalizationManager.shared.rating(detail.voteAverage))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.amber.opacity(0.15), in: .capsule)
            }

            if let episodes = detail.numberOfEpisodes, episodes > 0 {
                metaBadge(icon: "list.number", text: episodesText(episodes))
            }
        }
    }

    private func seasonsText(_ count: Int) -> String {
        count == 1 ? L("tv.seasons.one") : LF("tv.seasons", count)
    }

    private func episodesText(_ count: Int) -> String {
        count == 1 ? L("tv.episodes.one") : LF("tv.episodes", count)
    }

    // MARK: - Next episode

    /// Highlight card with the next episode's air date; the time appears
    /// only when TMDB actually returns one — never invented.
    private func nextEpisodeCard(_ episode: TMDBTVEpisodeInfo, formatted: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.tabCinema)
                .frame(width: 36, height: 36)
                .background(Theme.tabCinema.opacity(0.14), in: .rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(LF("tv.nextEpisode", formatted))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)

                if let reference = episode.episodeReference {
                    Text(episode.name?.isEmpty == false ? "\(reference) — \(episode.name ?? "")" : reference)
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Theme.card, in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.tabCinema.opacity(0.20), lineWidth: 1)
        )
    }

    // MARK: - Follow (new-episode alerts)

    private var isFollowing: Bool { TVFollowStore.shared.isFollowing(show.id) }

    /// "Avvisami sui nuovi episodi": follows the series for a local alert
    /// on the day TMDB says a new episode airs (Premium feature, like the
    /// whole TV section). The alert deep-links back to this page.
    private var followSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            LibraryActionButton(
                title: isFollowing ? L("tv.following") : L("tv.follow"),
                icon: isFollowing ? "bell.fill" : "bell",
                tint: Theme.tabCinema,
                isActive: isFollowing
            ) {
                let turningOn = !isFollowing
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    TVFollowStore.shared.toggle(
                        id: show.id, name: show.name, posterPath: show.posterPath
                    )
                }
                AnalyticsService.shared.log("tv_follow", meta: ["state": turningOn ? "on" : "off"])
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: isFollowing)

            if isFollowing {
                Text(L("tv.follow.hint"))
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Trailer

    private func watchTrailerButton(_ trailer: TMDBVideo) -> some View {
        Button {
            trailerToPlay = trailer
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                Text(L("trailer.watchLong"))
                    .font(.headline)
            }
            .foregroundStyle(Theme.inkInverse)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                LinearGradient(
                    colors: [Theme.ink, Theme.ink.opacity(0.85)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: .rect(cornerRadius: 18)
            )
            .shadow(color: Theme.ink.opacity(0.3), radius: 10, y: 5)
        }
        .buttonStyle(PressableCardStyle())
        .sensoryFeedback(.impact(weight: .medium), trigger: trailerToPlay)
    }

    // MARK: - Sections

    private func metaBadge(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.primary)
            Text(text)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.card, in: .capsule)
        .overlay(
            Capsule().stroke(Theme.primary.opacity(0.12), lineWidth: 1)
        )
    }

    private func genreChips(_ genres: [TMDBGenreInfo]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(genres) { genre in
                    Text(genre.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Theme.primary.opacity(0.10), in: .capsule)
                }
            }
        }
    }

    private func overviewSection(_ overview: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(L("detail.plot"))
            Text(overview)
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .lineSpacing(4)
        }
    }

    private func castSection(_ cast: [TMDBCastMember]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(L("detail.cast"))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(cast) { member in
                        CastMemberCard(member: member)
                    }
                }
            }
            .padding(.horizontal, -24)
            .contentMargins(.horizontal, 24)
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.title3.weight(.bold))
            .foregroundStyle(Theme.ink)
    }
}

#Preview {
    NavigationStack {
        TVShowDetailView(
            show: TMDBTVShow(
                id: 1396,
                name: "Breaking Bad",
                overview: "Un professore di chimica si trasforma.",
                posterPath: nil,
                backdropPath: nil,
                firstAirDate: "2008-01-20",
                voteAverage: 8.9,
                voteCount: 12000,
                genreIds: [18, 80]
            )
        )
    }
}
