//
//  MovieResultsView.swift
//  MoodE
//

import SwiftUI

/// Results screen: shows TMDB movies matching the user's mood flow choices.
struct MovieResultsView: View {
    let selection: MoodSelection

    @State private var viewModel = MovieResultsViewModel()
    @State private var trailerPlayback = TrailerPlayback()
    @Environment(MovieLibrary.self) private var library
    @Environment(MoodDiary.self) private var diary
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            switch viewModel.state {
            case .loading:
                loadingView
            case .failed(let message):
                errorView(message)
            case .loaded(let movies):
                if movies.isEmpty {
                    emptyView
                } else {
                    resultsList(movies)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AdBannerView()
        }
        .navigationTitle(L("results.title"))
        .toolbarTitleDisplayMode(.inline)
        .tint(Theme.primary)
        .navigationDestination(for: TMDBMovie.self) { movie in
            MovieDetailView(movie: movie)
        }
        .task {
            await viewModel.load(selection: selection, excluding: library.watchedIds)
            // Diary check-in: records date, mood, goal and proposed movies locally.
            if case .loaded(let movies) = viewModel.state, !movies.isEmpty {
                diary.record(selection: selection, proposed: movies)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await viewModel.refreshIfStale(selection: selection, excluding: library.watchedIds) }
        }
        .onChange(of: LocalizationManager.shared.language) { _, _ in
            // Language switch: refetch the batch localized in the new language.
            Task { await viewModel.load(selection: selection, excluding: library.watchedIds, forceRefresh: true) }
        }
        .trailerPlayer(trailerPlayback)
    }

    // MARK: - States

    private var loadingView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                recapChips

                Text(L("results.searching"))
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.horizontal, 24)

                SkeletonResultsList()
                    .padding(.horizontal, 24)
            }
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
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
                Task { await viewModel.load(selection: selection, excluding: library.watchedIds, forceRefresh: true) }
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

    private var emptyView: some View {
        VStack(spacing: 14) {
            Text("🎬")
                .font(.system(size: 48))
            Text(L("results.empty.title"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text(
                StreamingServicesStore.shared.isFilterActive
                    ? L("results.empty.filtered")
                    : L("results.empty.msg")
            )
            .font(.subheadline)
            .foregroundStyle(Theme.inkSoft)
            .multilineTextAlignment(.center)

            if StreamingServicesStore.shared.isFilterActive {
                Button {
                    StreamingServicesStore.shared.setFilterEnabled(false)
                    Task { await viewModel.load(selection: selection, excluding: library.watchedIds) }
                } label: {
                    Label(L("filter.streaming.off"), systemImage: "line.3.horizontal.decrease.circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 11)
                        .background(Theme.primary, in: .capsule)
                }
            }
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Results

    private func resultsList(_ movies: [TMDBMovie]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    recapChips
                        .id("top")

                    Text(L("results.chosen"))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 24)

                    LazyVStack(spacing: 14) {
                        ForEach(movies) { movie in
                            MovieCard(
                                movie: movie,
                                isLoadingTrailer: trailerPlayback.loadingMovieId == movie.id,
                                onPlayTrailer: { trailerPlayback.play(movie) }
                            )
                        }
                    }
                    .sensoryFeedback(.impact(weight: .medium), trigger: trailerPlayback.loadingMovieId)
                    .padding(.horizontal, 24)

                    if PremiumStore.shared.isPremium || AdsManager.shared.isRewardedReady || viewModel.isLoadingBonus {
                        rewardedButton
                    }

                    newBatchButton
                }
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .onChange(of: viewModel.batchId) { _, _ in
                withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
                    proxy.scrollTo("top", anchor: .top)
                }
            }
        }
    }

    /// Rewarded ad: watching a short video unlocks 5 extra picks
    /// appended below the current batch.
    private var rewardedButton: some View {
        Button {
            if PremiumStore.shared.isPremium {
                // Premium: bonus immediato, senza video pubblicitario.
                Task {
                    await viewModel.loadBonusMovies(selection: selection, excluding: library.watchedIds)
                }
            } else {
                AdsManager.shared.showRewarded {
                    Task {
                        await viewModel.loadBonusMovies(selection: selection, excluding: library.watchedIds)
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                if viewModel.isLoadingBonus {
                    ProgressView()
                        .tint(Theme.amber)
                } else {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(L(PremiumStore.shared.isPremium ? "results.bonus.premium" : "results.rewarded"))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .foregroundStyle(Theme.amber)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .padding(.horizontal, 14)
            .background(Theme.amber.opacity(0.12), in: .rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.amber.opacity(0.35), lineWidth: 1)
            )
        }
        .disabled(viewModel.isLoadingBonus)
        .sensoryFeedback(.impact(weight: .medium), trigger: viewModel.isLoadingBonus)
        .padding(.horizontal, 24)

    }

    /// Reruns the same filters on the next discover page for fresh picks.
    private var newBatchButton: some View {
        Button {
            Task { await viewModel.loadNewBatch(selection: selection, excluding: library.watchedIds) }
        } label: {
            HStack(spacing: 8) {
                if viewModel.isRefreshing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(L("results.newBatch"))
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                viewModel.isRefreshing ? Theme.primary.opacity(0.6) : Theme.primary,
                in: .rect(cornerRadius: 18)
            )
        }
        .disabled(viewModel.isRefreshing)
        .sensoryFeedback(.impact(weight: .medium), trigger: viewModel.batchId)
        .padding(.horizontal, 24)
        .padding(.top, 6)
    }

    private var recapChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                recapChip(emoji: selection.mood.emoji, text: selection.mood.title)
                recapChip(emoji: selection.goal.emoji, text: selection.goal.title)
                // One chip per chosen era (step 3 is multi-select).
                ForEach(selection.eras) { era in
                    recapChip(emoji: era.emoji, text: era.title)
                }

                if StreamingServicesStore.shared.isFilterActive {
                    streamingFilterChip
                }
            }
        }
        .contentMargins(.horizontal, 24)
    }

    /// Green chip signalling that results are limited to the user's
    /// streaming services, so a short list never looks like a bug.
    private var streamingFilterChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "play.tv.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.seenGreen)
            Text(L("filter.streaming.only"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.seenGreen.opacity(0.12), in: .capsule)
        .overlay(
            Capsule().stroke(Theme.seenGreen.opacity(0.35), lineWidth: 1)
        )
    }

    private func recapChip(emoji: String, text: String) -> some View {
        HStack(spacing: 6) {
            Text(emoji)
            Text(text)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.card, in: .capsule)
        .overlay(
            Capsule().stroke(Theme.primary.opacity(0.15), lineWidth: 1)
        )
    }
}

/// Trailer ready to be played from a results card.
struct TrailerSelection: Identifiable {
    let movieTitle: String
    let trailer: TMDBVideo

    var id: String { trailer.id }
}

/// Card showing a single movie with poster, rating and overview.
/// The poster + info area is a NavigationLink to the full detail page;
/// the action buttons (save/seen/share/trailer) live OUTSIDE the link
/// so their taps never conflict with navigation. Keeping the ShareLink
/// out of the NavigationLink label is what makes the card tappable
/// (a nested ShareLink used to swallow every tap on the card).
struct MovieCard: View {
    let movie: TMDBMovie
    var isLoadingTrailer: Bool = false
    var onPlayTrailer: (() -> Void)? = nil

    @Environment(MovieLibrary.self) private var library

    private var isInWatchlist: Bool { library.isInWatchlist(movie.id) }
    private var isSeen: Bool { library.isSeen(movie.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NavigationLink(value: movie) {
                openableArea
                    .contentShape(.rect)
            }
            .buttonStyle(PressableCardStyle())
            .accessibilityHint(L("card.a11y.openDetail"))

            quickActions

            if let onPlayTrailer {
                WatchTrailerButton(
                    tint: Theme.rose,
                    isLoading: isLoadingTrailer,
                    action: onPlayTrailer
                )
            }
        }
        .padding(12)
        .background(Theme.card, in: .rect(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Theme.primary.opacity(0.10), lineWidth: 1)
        )
        .sensoryFeedback(.impact(weight: .medium), trigger: isInWatchlist)
        .sensoryFeedback(.success, trigger: isSeen)
    }

    /// Poster, title, year, rating, genres and overview: tapping anywhere
    /// here opens the movie detail page (with press-down feedback).
    private var openableArea: some View {
        HStack(alignment: .top, spacing: 14) {
            poster

            VStack(alignment: .leading, spacing: 6) {
                Text(movie.title)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 8) {
                    if let year = movie.releaseYear {
                        Text(year)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.inkSoft)
                    }

                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.amber)
                        Text(LocalizationManager.shared.rating(movie.voteAverage))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.amber.opacity(0.15), in: .capsule)
                }

                if !movie.genreNames.isEmpty {
                    Text(movie.genreNames.prefix(3).joined(separator: " · "))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.primary)
                        .lineLimit(1)
                }

                if !movie.overview.isEmpty {
                    Text(movie.overview)
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                        .lineLimit(3)
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)
                }

                ProviderStripView(movieId: movie.id)
                    .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
    }

    /// Quick save / seen toggles usable directly from the results list.
    /// Full card width: the two text chips share the row equally so their
    /// labels ("Salva", "Già visto") are never truncated.
    private var quickActions: some View {
        HStack(spacing: 8) {
            QuickActionChip(
                title: isInWatchlist ? L("card.saved") : L("card.save"),
                icon: isInWatchlist ? "bookmark.fill" : "bookmark",
                tint: Theme.primary,
                isActive: isInWatchlist,
                expands: true
            ) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    library.toggleWatchlist(movie)
                }
            }

            QuickActionChip(
                title: isSeen ? L("card.watched") : L("card.seen"),
                icon: isSeen ? "checkmark.circle.fill" : "checkmark.circle",
                tint: Theme.seenGreen,
                isActive: isSeen,
                expands: true
            ) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    library.toggleSeen(movie)
                }
            }

            MovieShareButton(
                movieTitle: movie.title,
                message: movie.shareMessage,
                tint: Theme.primary
            )
        }
    }

    private var poster: some View {
        Color(Theme.surface)
            .frame(width: 92, height: 132)
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
                                .tint(Theme.primary)
                        }
                    }
                } else {
                    posterFallback
                }
            }
            .clipShape(.rect(cornerRadius: 14))
            .overlay(alignment: .topLeading) {
                AvailableNowBadge(movieId: movie.id)
                    .padding(5)
            }
            .overlay(alignment: .bottomLeading) {
                if let onPlayTrailer {
                    Button(action: onPlayTrailer) {
                        ZStack {
                            Circle()
                                .fill(.black.opacity(0.5))
                                .background(.ultraThinMaterial, in: .circle)

                            if isLoadingTrailer {
                                ProgressView()
                                    .tint(.white)
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white)
                                    .offset(x: 1)
                            }
                        }
                        .frame(width: 34, height: 34)
                        .overlay(
                            Circle().stroke(.white.opacity(0.55), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
                        .padding(6)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L("trailer.watchLong"))
                }
            }
    }

    private var posterFallback: some View {
        Image(systemName: "film")
            .font(.system(size: 26))
            .foregroundStyle(Theme.primary.opacity(0.4))
    }
}

/// Compact toggle chip for quick library actions on a results card.
/// With `expands` the chip stretches to share the row, so labels are
/// always fully readable (scaling down slightly before ever truncating).
struct QuickActionChip: View {
    let title: String
    let icon: String
    let tint: Color
    let isActive: Bool
    var expands: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .contentTransition(.symbolEffect(.replace))
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isActive ? .white : tint)
            .padding(.horizontal, 11)
            .frame(height: 32)
            .frame(maxWidth: expands ? .infinity : nil)
            .background(
                isActive ? tint : tint.opacity(0.10),
                in: .capsule
            )
            .overlay(
                Capsule().stroke(tint.opacity(isActive ? 0 : 0.35), lineWidth: 1)
            )
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

#Preview {
    NavigationStack {
        MovieResultsView(
            selection: MoodSelection(mood: .felice, goal: .ridere, era: .nineties)
        )
    }
    .environment(MovieLibrary())
    .environment(MoodDiary())
}
