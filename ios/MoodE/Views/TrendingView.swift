//
//  TrendingView.swift
//  MoodE
//

import SwiftUI

/// Tendenze tab: trending movies from TMDB with a week/day selector.
struct TrendingView: View {
    @State private var viewModel = TrendingViewModel()
    @State private var trailerPlayback = TrailerPlayback()
    @Environment(MovieLibrary.self) private var library
    @Environment(\.scenePhase) private var scenePhase

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                content
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                AdBannerView()
            }
            .navigationTitle(L("tab.trending"))
            .toolbarTitleDisplayMode(.large)
            .navigationDestination(for: TMDBMovie.self) { movie in
                MovieDetailView(movie: movie)
            }
            .trailerPlayer(trailerPlayback)
        }
        .tint(Theme.tabTrending)
        .task {
            if case .idle = viewModel.state {
                await viewModel.load()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await viewModel.refreshIfStale() }
        }
        .onChange(of: LocalizationManager.shared.language) { _, _ in
            // Language switch: refetch trending data localized in the new language.
            Task { await viewModel.reloadForLanguage() }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            loadingView
        case .failed(let message):
            errorView(message)
        case .loaded(let movies):
            moviesGrid(movies.filter { !library.watchedIds.contains($0.id) })
        }
    }

    private var loadingView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                windowSelector

                SkeletonPosterGrid()
                    .padding(.horizontal, 24)
            }
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(Theme.tabTrending)
            Text(L("common.oops"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
            Button {
                Task { await viewModel.load(forceRefresh: true) }
            } label: {
                Label(L("common.retry"), systemImage: "arrow.clockwise")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Theme.tabTrending, in: .capsule)
            }
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Grid

    private func moviesGrid(_ movies: [TMDBMovie]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                windowSelector

                if movies.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(Array(movies.enumerated()), id: \.element.id) { index, movie in
                            NavigationLink(value: movie) {
                                TrendingCard(
                                    movie: movie,
                                    rank: index + 1,
                                    isLoadingTrailer: trailerPlayback.loadingMovieId == movie.id,
                                    onPlayTrailer: { trailerPlayback.play(movie) }
                                )
                            }
                            .buttonStyle(PressableCardStyle())
                        }
                    }
                    .padding(.horizontal, 24)
                    .animation(.spring(duration: 0.3), value: movies)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await viewModel.load(forceRefresh: true)
        }
    }

    // MARK: - Window selector

    private var windowSelector: some View {
        HStack(spacing: 8) {
            ForEach(TrendingWindow.allCases) { window in
                WindowSelectorChip(
                    label: window.label,
                    icon: window == .week ? "calendar" : "sun.max.fill",
                    isSelected: viewModel.window == window
                ) {
                    guard viewModel.window != window else { return }
                    viewModel.window = window
                    Task { await viewModel.load() }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("🔥")
                .font(.system(size: 44))
            Text(L("trending.empty.title"))
                .font(.headline)
                .foregroundStyle(Theme.ink)
            Text(L("trending.empty.msg"))
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
    }
}

/// Pill chip for the week/day trending selector.
struct WindowSelectorChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(label)
                    .font(.subheadline.weight(isSelected ? .bold : .medium))
            }
            .foregroundStyle(isSelected ? .white : Theme.tabTrending)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(
                isSelected ? Theme.tabTrending : Theme.tabTrending.opacity(0.10),
                in: .capsule
            )
            .overlay(
                Capsule()
                    .stroke(Theme.tabTrending.opacity(isSelected ? 0 : 0.25), lineWidth: 1)
            )
        }
        .buttonStyle(PressableCardStyle())
        .sensoryFeedback(.selection, trigger: isSelected)
        .animation(.spring(duration: 0.25), value: isSelected)
        .accessibilityLabel(LF("trending.a11y.show", label))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Grid card for a trending movie: poster with rank badge, title and TMDB rating.
struct TrendingCard: View {
    let movie: TMDBMovie
    var rank: Int? = nil
    var isLoadingTrailer: Bool = false
    var onPlayTrailer: (() -> Void)? = nil

    /// Gold, silver and bronze for the podium; amber-orange for everyone else.
    private var rankColor: Color {
        switch rank {
        case 1: return Color(red: 0.85, green: 0.65, blue: 0.13)
        case 2: return Color(red: 0.55, green: 0.57, blue: 0.62)
        case 3: return Color(red: 0.72, green: 0.45, blue: 0.20)
        default: return Theme.tabTrending
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            poster

            Text(movie.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.amber)
                Text(LocalizationManager.shared.rating(movie.voteAverage))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                if let year = movie.releaseYear {
                    Text("· \(year)")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
            }

            if let onPlayTrailer {
                WatchTrailerButton(
                    tint: Theme.tabTrending,
                    isCompact: true,
                    isLoading: isLoadingTrailer,
                    action: onPlayTrailer
                )
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var poster: some View {
        Color(Theme.surface)
            .aspectRatio(2 / 3, contentMode: .fit)
            .overlay {
                if let url = movie.posterURL {
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
                                .tint(Theme.tabTrending)
                        }
                    }
                } else {
                    posterFallback
                }
            }
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.tabTrending.opacity(0.10), lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                MovieShareButton(
                    movieTitle: movie.title,
                    message: movie.shareMessage,
                    style: .posterOverlay
                )
                .padding(6)
            }
            .overlay(alignment: .topLeading) {
                if let rank {
                    rankBadge(rank)
                        .padding(6)
                }
            }
    }

    private func rankBadge(_ rank: Int) -> some View {
        HStack(spacing: 2) {
            if rank <= 3 {
                Image(systemName: "crown.fill")
                    .font(.system(size: 9, weight: .bold))
            }
            Text("\(rank)\u{00B0}")
                .font(.caption.weight(.heavy))
                .monospacedDigit()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(rankColor.opacity(0.92), in: .capsule)
        .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
        .accessibilityLabel(LF("trending.a11y.rank", rank))
    }

    private var posterFallback: some View {
        Image(systemName: "film")
            .font(.system(size: 30))
            .foregroundStyle(Theme.tabTrending.opacity(0.4))
    }
}

#Preview {
    TrendingView()
        .environment(MovieLibrary())
}
