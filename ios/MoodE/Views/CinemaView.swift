//
//  CinemaView.swift
//  MoodE
//

import SwiftUI
import CoreLocation

/// Al Cinema tab: now-playing movies for the user's country plus
/// a placeholder for nearby cinema showtimes.
struct CinemaView: View {
    @State private var locationService = LocationService()
    @State private var viewModel = CinemaViewModel()
    /// Persisted so "Non ora" is remembered across launches: the tab then
    /// always falls back to national now-playing results (device country, default IT).
    @AppStorage("cinema.skippedPermission") private var skippedPermission: Bool = false
    @State private var cinemaSearchText = ""
    @State private var selectedGenreId: Int?
    @State private var trailerPlayback = TrailerPlayback()
    @Environment(\.openURL) private var openURL
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
            .navigationTitle(L("tab.cinema"))
            .toolbarTitleDisplayMode(.large)
            .navigationDestination(for: TMDBMovie.self) { movie in
                MovieDetailView(movie: movie)
            }
            .trailerPlayer(trailerPlayback)
        }
        .tint(Theme.tabCinema)
        .onChange(of: locationService.authorizationStatus) { oldStatus, newStatus in
            guard oldStatus == .notDetermined, newStatus != .notDetermined else { return }
            Task { await loadMovies() }
        }
        .task {
            let canLoad = locationService.authorizationStatus != .notDetermined || skippedPermission
            if canLoad, case .idle = viewModel.state {
                await loadMovies()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await viewModel.refreshIfStale() }
        }
        .onChange(of: LocalizationManager.shared.language) { _, _ in
            // Language switch: refetch now-playing data localized in the new language.
            Task { await loadMovies(forceRefresh: true) }
        }
    }

    // MARK: - Loading

    private func loadMovies(forceRefresh: Bool = false) async {
        let region = await resolveRegion()
        await viewModel.load(region: region, forceRefresh: forceRefresh)
        await loadNearbyCinemas()
    }

    /// Loads nearby cinema names via Apple Maps when location is available.
    private func loadNearbyCinemas() async {
        guard locationService.isAuthorized,
              let location = await locationService.resolveLocation() else { return }
        await viewModel.loadNearbyCinemas(around: location)
    }

    /// Country from the user's position when authorized, otherwise device locale.
    private func resolveRegion() async -> String {
        if locationService.isAuthorized,
           let code = await locationService.resolveCountryCode() {
            return code
        }
        return Locale.current.region?.identifier ?? "IT"
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if locationService.authorizationStatus == .notDetermined && !skippedPermission {
            permissionIntro
        } else {
            switch viewModel.state {
            case .idle, .loading:
                loadingView
            case .failed(let message):
                errorView(message)
            case .loaded(let movies):
                moviesList(movies)
            }
        }
    }

    // MARK: - Permission intro

    private var permissionIntro: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.tabCinema.opacity(0.14))
                    .frame(width: 130, height: 130)
                Circle()
                    .fill(Theme.tabCinema.opacity(0.10))
                    .frame(width: 170, height: 170)
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Theme.tabCinema)
            }

            VStack(spacing: 12) {
                Text(L("cinema.perm.title"))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)

                Text(L("cinema.perm.msg"))
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            VStack(spacing: 12) {
                Button {
                    locationService.requestPermission()
                } label: {
                    Label(L("cinema.perm.allow"), systemImage: "location.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Theme.tabCinema, in: .rect(cornerRadius: 18))
                        .shadow(color: Theme.tabCinema.opacity(0.35), radius: 10, y: 5)
                }
                .buttonStyle(PressableCardStyle())

                Button {
                    skippedPermission = true
                    Task { await loadMovies() }
                } label: {
                    Text(L("cinema.perm.notNow"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.inkSoft)
                        .frame(height: 40)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - States

    private var loadingView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 8) {
                    Image(systemName: "ticket.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.tabCinema)
                    Text(L("cinema.loading"))
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                }
                .padding(.horizontal, 24)

                SkeletonPosterGrid(showsChipsRow: true)
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
                .foregroundStyle(Theme.tabCinema)
            Text(L("common.oops"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
            Button {
                Task { await loadMovies(forceRefresh: true) }
            } label: {
                Label(L("common.retry"), systemImage: "arrow.clockwise")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Theme.tabCinema, in: .capsule)
            }
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Movies list

    private func moviesList(_ movies: [TMDBMovie]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if locationService.isDenied {
                    deniedBanner
                }

                regionHeader

                if movies.isEmpty {
                    emptyState
                } else {
                    genreChips(for: movies)

                    let filteredMovies = filteredByGenre(movies)

                    if filteredMovies.isEmpty {
                        noGenreResultsCard
                    } else {
                        LazyVGrid(columns: columns, spacing: 18) {
                            ForEach(filteredMovies) { movie in
                                NavigationLink(value: movie) {
                                    NowPlayingCard(
                                        movie: movie,
                                        isLoadingTrailer: trailerPlayback.loadingMovieId == movie.id,
                                        onPlayTrailer: { trailerPlayback.play(movie) }
                                    )
                                }
                                .buttonStyle(PressableCardStyle())
                            }
                        }
                        .padding(.horizontal, 24)
                        .animation(.spring(duration: 0.3), value: filteredMovies)
                    }
                }

                nearbyCinemasSection
            }
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await loadMovies(forceRefresh: true)
        }
    }

    // MARK: - Genre filter

    /// Genres present in the loaded movies, sorted alphabetically by localized name.
    private func availableGenres(in movies: [TMDBMovie]) -> [(id: Int, name: String)] {
        var counts: [Int: Int] = [:]
        for movie in movies {
            for genreId in movie.genreIds ?? [] {
                counts[genreId, default: 0] += 1
            }
        }
        return counts.keys
            .compactMap { id -> (id: Int, name: String)? in
                guard let name = TMDBGenreCatalog.name(for: id) else { return nil }
                return (id: id, name: name)
            }
            .sorted { $0.name < $1.name }
    }

    private func filteredByGenre(_ movies: [TMDBMovie]) -> [TMDBMovie] {
        guard let selectedGenreId else { return movies }
        return movies.filter { ($0.genreIds ?? []).contains(selectedGenreId) }
    }

    private func genreChips(for movies: [TMDBMovie]) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                GenreChip(
                    label: L("cinema.all"),
                    icon: "sparkles",
                    isSelected: selectedGenreId == nil
                ) {
                    selectedGenreId = nil
                }

                ForEach(availableGenres(in: movies), id: \.id) { genre in
                    GenreChip(
                        label: genre.name,
                        icon: nil,
                        isSelected: selectedGenreId == genre.id
                    ) {
                        selectedGenreId = selectedGenreId == genre.id ? nil : genre.id
                    }
                }
            }
        }
        .contentMargins(.horizontal, 24)
        .scrollIndicators(.hidden)
    }

    private var noGenreResultsCard: some View {
        VStack(spacing: 10) {
            Text("🎬")
                .font(.system(size: 36))
            Text(L("cinema.noGenre"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Button(L("cinema.showAll")) {
                withAnimation(.spring(duration: 0.3)) {
                    selectedGenreId = nil
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.tabCinema)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 24)
    }

    private var regionHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "ticket.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.tabCinema)
            Text(LF("cinema.inTheatres", viewModel.regionName))
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 24)
    }

    private var deniedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 16))
                .foregroundStyle(Theme.tabCinema)

            Text(L("cinema.denied"))
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)

            Spacer()

            Button(L("cinema.settings")) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.tabCinema)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.card, in: .rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.tabCinema.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("🎟️")
                .font(.system(size: 44))
            Text(L("cinema.empty.title"))
                .font(.headline)
                .foregroundStyle(Theme.ink)
            Text(L("cinema.empty.msg"))
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
    }

    /// Nearby cinemas found via Apple Maps, with a note that showtimes are coming.
    private var nearbyCinemasSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.tabCinema)
                Text(L("cinema.nearby"))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.ink)
            }

            switch viewModel.cinemasState {
            case .loading:
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(Theme.tabCinema)
                    Text(L("cinema.searchingNearby"))
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Theme.card, in: .rect(cornerRadius: 20))

            case .loaded(let cinemas):
                cinemaSearchBar

                let filtered = filteredCinemas(cinemas)

                if filtered.isEmpty {
                    noSearchResultsCard
                } else {
                    VStack(spacing: 10) {
                        ForEach(filtered) { cinema in
                            NearbyCinemaRow(cinema: cinema)
                        }
                    }
                    .animation(.spring(duration: 0.3), value: filtered)
                }

                showtimesComingNote

            case .idle, .unavailable:
                fallbackCinemaCard
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    /// Filters nearby cinemas by name (and address) using the search text.
    private func filteredCinemas(_ cinemas: [NearbyCinema]) -> [NearbyCinema] {
        let query = cinemaSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return cinemas }
        return cinemas.filter { cinema in
            cinema.name.localizedStandardContains(query)
            || (cinema.address?.localizedStandardContains(query) ?? false)
        }
    }

    private var cinemaSearchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.tabCinema)

            TextField(L("cinema.searchPlaceholder"), text: $cinemaSearchText)
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !cinemaSearchText.isEmpty {
                Button {
                    withAnimation(.spring(duration: 0.25)) {
                        cinemaSearchText = ""
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
                .stroke(Theme.tabCinema.opacity(0.18), lineWidth: 1)
        )
    }

    private var noSearchResultsCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18))
                .foregroundStyle(Theme.tabCinema.opacity(0.6))
            Text(LF("cinema.noMatch", cinemaSearchText.trimmingCharacters(in: .whitespacesAndNewlines)))
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Theme.card, in: .rect(cornerRadius: 16))
    }

    private var showtimesComingNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 14))
                .foregroundStyle(Theme.tabCinema)
            Text(L("cinema.soon"))
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
        }
        .padding(.top, 2)
    }

    private var fallbackCinemaCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.tabCinema.opacity(0.12))
                    .frame(width: 52, height: 52)
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.tabCinema)
            }

            Text(locationService.isAuthorized
                 ? L("cinema.noneFound")
                 : L("cinema.enableLocation"))
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .lineSpacing(2)

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Theme.card, in: .rect(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.tabCinema.opacity(0.12), lineWidth: 1)
        )
    }
}

/// Pill-shaped chip for the genre quick filter above the now-playing grid.
struct GenreChip: View {
    let label: String
    let icon: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(label)
                    .font(.subheadline.weight(isSelected ? .bold : .medium))
            }
            .foregroundStyle(isSelected ? .white : Theme.tabCinema)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                isSelected ? Theme.tabCinema : Theme.tabCinema.opacity(0.10),
                in: .capsule
            )
            .overlay(
                Capsule()
                    .stroke(Theme.tabCinema.opacity(isSelected ? 0 : 0.25), lineWidth: 1)
            )
        }
        .buttonStyle(PressableCardStyle())
        .sensoryFeedback(.selection, trigger: isSelected)
        .animation(.spring(duration: 0.25), value: isSelected)
        .accessibilityLabel(LF("cinema.a11y.genre", label))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Tappable row for a nearby cinema: opens Apple Maps with driving directions.
struct NearbyCinemaRow: View {
    let cinema: NearbyCinema

    @State private var tapCount = 0

    var body: some View {
        Button {
            tapCount += 1
            cinema.openDirectionsInMaps()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.tabCinema.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "popcorn.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.tabCinema)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(cinema.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)

                    if let address = cinema.address {
                        Text(address)
                            .font(.caption)
                            .foregroundStyle(Theme.inkSoft)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 5) {
                    if let distance = cinema.formattedDistance {
                        Text(distance)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.tabCinema)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Theme.tabCinema.opacity(0.12), in: .capsule)
                    }

                    HStack(spacing: 3) {
                        Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                            .font(.system(size: 11))
                        Text(L("cinema.directions"))
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(Theme.tabCinema.opacity(0.85))
                }
            }
            .padding(12)
            .background(Theme.card, in: .rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.tabCinema.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(PressableCardStyle())
        .sensoryFeedback(.impact(weight: .light), trigger: tapCount)
        .accessibilityLabel(LF("cinema.a11y.directions", cinema.name))
    }
}

/// Grid card for a now-playing movie: poster, title and release date.
struct NowPlayingCard: View {
    let movie: TMDBMovie
    var isLoadingTrailer: Bool = false
    var onPlayTrailer: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            poster

            Text(movie.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            if let date = movie.formattedReleaseDate {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.tabCinema)
                    Text(date)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Theme.inkSoft)
                }
            }

            if let onPlayTrailer {
                WatchTrailerButton(
                    tint: Theme.tabCinema,
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
                                .tint(Theme.tabCinema)
                        }
                    }
                } else {
                    posterFallback
                }
            }
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.tabCinema.opacity(0.10), lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                MovieShareButton(
                    movieTitle: movie.title,
                    message: movie.shareMessage,
                    style: .posterOverlay
                )
                .padding(6)
            }
    }

    private var posterFallback: some View {
        Image(systemName: "film")
            .font(.system(size: 30))
            .foregroundStyle(Theme.tabCinema.opacity(0.4))
    }
}

#Preview {
    CinemaView()
        .environment(MovieLibrary())
}
