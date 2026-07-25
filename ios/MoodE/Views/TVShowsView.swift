//
//  TVShowsView.swift
//  MoodE
//

import SwiftUI

/// "Emissioni televisive": Premium-only TV series section hosted by the
/// Tendenze tab. Four TMDB categories (popular, airing today, on the air,
/// top rated) behind a chip selector, with per-show streaming availability
/// and the next-episode air date for the schedule-driven categories.
struct TVShowsView: View {
    @State private var viewModel = TVShowsViewModel()
    @State private var showPaywall = false
    @State private var searchQuery = ""
    @State private var searchResults: [TMDBTVShow] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @Environment(\.scenePhase) private var scenePhase

    private var premium: PremiumStore { .shared }
    private var history: SearchHistory { .tv }

    private var trimmedQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        Group {
            if premium.isPremium {
                content
            } else {
                lockedState
            }
        }
        .task {
            guard premium.isPremium else { return }
            if case .idle = viewModel.state {
                await viewModel.load()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active, premium.isPremium else { return }
            Task { await viewModel.refreshIfStale() }
        }
        .onChange(of: LocalizationManager.shared.language) { _, _ in
            guard premium.isPremium else { return }
            Task { await viewModel.reloadForLanguage() }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    // MARK: - Content

    private var content: some View {
        VStack(spacing: 0) {
            searchBar
                .padding(.horizontal, 24)
                .padding(.top, 8)

            if trimmedQuery.isEmpty && !history.items.isEmpty {
                RecentSearchesRow(history: history, tint: Theme.tabTrending) { term in
                    searchQuery = term
                    history.add(term)
                }
                .padding(.top, 10)
            }

            if !trimmedQuery.isEmpty {
                searchContent
                    .padding(.top, 10)
            } else {
                categoryContent
                    .padding(.top, 10)
            }
        }
    }

    @ViewBuilder
    private var categoryContent: some View {
        switch viewModel.state {
        case .idle, .loading:
            loadingView
        case .failed(let message):
            errorView(message)
        case .loaded(let shows):
            showsGrid(shows)
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.tabTrending)

            TextField(L("tv.search.placeholder"), text: $searchQuery)
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit {
                    guard !trimmedQuery.isEmpty else { return }
                    history.add(trimmedQuery)
                    AnalyticsService.shared.log("tv_search")
                }

            if !searchQuery.isEmpty {
                Button {
                    withAnimation(.spring(duration: 0.25)) {
                        searchQuery = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.inkSoft.opacity(0.6))
                }
                .accessibilityLabel(L("cinema.clearSearch"))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Theme.cardStrong, in: .rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.tabTrending.opacity(0.18), lineWidth: 1)
        )
        .onChange(of: searchQuery) { _, newValue in
            scheduleSearch(newValue)
        }
    }

    /// Debounced remote search: waits for a typing pause, then queries TMDB.
    private func scheduleSearch(_ query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        isSearching = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            let results = (try? await TMDBService.searchTVShows(query: trimmed)) ?? []
            guard !Task.isCancelled else { return }
            withAnimation(.spring(duration: 0.3)) {
                searchResults = results
                isSearching = false
            }
        }
    }

    // MARK: - Search results

    @ViewBuilder
    private var searchContent: some View {
        if isSearching {
            HStack(spacing: 12) {
                ProgressView()
                    .tint(Theme.tabTrending)
                Text(L("tv.search.searching"))
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            Spacer(minLength: 0)
        } else if searchResults.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "tv")
                    .font(.system(size: 36))
                    .foregroundStyle(Theme.tabTrending.opacity(0.5))
                Text(LF("tv.search.noResults", trimmedQuery))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .padding(.horizontal, 24)
            Spacer(minLength: 0)
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(searchResults) { show in
                        NavigationLink(value: show) {
                            TVShowCard(show: show, showsNextEpisode: false)
                        }
                        .buttonStyle(PressableCardStyle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var loadingView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                categorySelector

                SkeletonPosterGrid()
                    .padding(.horizontal, 24)
            }
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
        .frame(maxHeight: .infinity)
    }

    // MARK: - Grid

    private func showsGrid(_ shows: [TMDBTVShow]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                categorySelector

                if shows.isEmpty {

                    emptyState
                } else {
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(shows) { show in
                            NavigationLink(value: show) {
                                TVShowCard(
                                    show: show,
                                    showsNextEpisode: viewModel.category.showsNextEpisode
                                )
                            }
                            .buttonStyle(PressableCardStyle())
                        }
                    }
                    .padding(.horizontal, 24)
                    .animation(.spring(duration: 0.3), value: shows)
                }
            }
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await viewModel.load(forceRefresh: true)
        }
    }

    // MARK: - Category selector

    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TVCategory.allCases) { category in
                    WindowSelectorChip(
                        label: category.label,
                        icon: category.icon,
                        isSelected: viewModel.category == category
                    ) {
                        guard viewModel.category != category else { return }
                        viewModel.category = category
                        AnalyticsService.shared.log("tv_category", meta: ["category": category.rawValue])
                        Task { await viewModel.load() }
                    }
                }
            }
        }
        .contentMargins(.horizontal, 24)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tv")
                .font(.system(size: 40))
                .foregroundStyle(Theme.tabTrending.opacity(0.5))
            Text(L("tv.empty.title"))
                .font(.headline)
                .foregroundStyle(Theme.ink)
            Text(L("tv.empty.msg"))
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
    }

    // MARK: - Locked (Premium lapsed while the section was reachable)

    private var lockedState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Theme.amber.opacity(0.18))
                    .frame(width: 76, height: 76)
                Image(systemName: "lock.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Theme.amber)
            }
            Text(L("tv.locked.title"))
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.ink)
            Text(L("tv.locked.msg"))
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
            Button {
                showPaywall = true
            } label: {
                Label(L("tv.locked.cta"), systemImage: "crown.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Theme.amber, Theme.rose],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: .capsule
                    )
            }
            .buttonStyle(PressableCardStyle())
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Grid card for a TV show: poster, title, rating, genres, streaming strip
/// and — for the airing categories — the next-episode air date.
struct TVShowCard: View {
    let show: TMDBTVShow
    let showsNextEpisode: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            poster

            Text(show.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.amber)
                Text(LocalizationManager.shared.rating(show.voteAverage))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                if let year = show.firstAirYear {
                    Text("· \(year)")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
            }

            if !show.genreNames.isEmpty {
                Text(show.genreNames.prefix(2).joined(separator: " \u{00B7} "))
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(1)
            }

            if showsNextEpisode {
                TVNextEpisodeLabel(showId: show.id)
            }

            TVProviderStripView(showId: show.id, tint: Theme.tabTrending)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var poster: some View {
        Color(Theme.surface)
            .aspectRatio(2 / 3, contentMode: .fit)
            .overlay {
                if let url = show.posterURL {
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
                    movieTitle: show.name,
                    message: show.shareMessage,
                    style: .posterOverlay
                )
                .padding(6)
            }
    }

    private var posterFallback: some View {
        Image(systemName: "tv")
            .font(.system(size: 30))
            .foregroundStyle(Theme.tabTrending.opacity(0.4))
    }
}

/// Lazy "Prossimo episodio: 24 luglio" line under a TV card. The time is
/// shown only when TMDB actually returns one — never invented.
struct TVNextEpisodeLabel: View {
    let showId: Int

    @State private var text: String?

    var body: some View {
        Group {
            if let text {
                HStack(spacing: 4) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.tabCinema)
                    Text(LF("tv.nextEpisode", text))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.tabCinema)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .transition(.opacity)
            }
        }
        .task(id: showId) {
            guard let info = await TVNextEpisodeCache.shared.nextEpisode(for: showId),
                  let formatted = info.formattedNextAiring else { return }
            withAnimation(.easeIn(duration: 0.2)) {
                text = formatted
            }
        }
    }
}

/// Compact strip of streaming-platform logos under a TV show card,
/// TV twin of `ProviderStripView` (separate cache namespace).
struct TVProviderStripView: View {
    let showId: Int
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
        .task(id: showId) {
            let fetched = await WatchProviderCache.shared.tvProviders(for: showId)
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

#Preview {
    NavigationStack {
        TVShowsView()
    }
}
