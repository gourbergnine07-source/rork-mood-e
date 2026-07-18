//
//  MovieDetailView.swift
//  MoodE
//

import SwiftUI

/// Detail screen: enlarged poster, runtime, main cast and official trailer.
struct MovieDetailView: View {
    let movie: TMDBMovie

    @State private var viewModel = MovieDetailViewModel()
    @State private var trailerToPlay: TMDBVideo?
    @Environment(MovieLibrary.self) private var library

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            switch viewModel.state {
            case .loading:
                loadingView
            case .failed(let message):
                errorView(message)
            case .loaded(let detail):
                detailContent(detail)
            }
        }
        .navigationTitle(movie.title)
        .toolbarTitleDisplayMode(.inline)
        .tint(Theme.primary)
        .task {
            await viewModel.load(movieID: movie.id)
        }
        .onChange(of: LocalizationManager.shared.language) { _, _ in
            // Language switch: reload the detail localized in the new language.
            Task { await viewModel.load(movieID: movie.id) }
        }
        .onDisappear {
            // Tornando ai risultati: interstitial al massimo 1 ogni 5 minuti.
            AdsManager.shared.maybeShowReturnInterstitial()
        }
        .sheet(item: $trailerToPlay) { trailer in
            TrailerPlayerSheet(trailer: trailer, movieTitle: movie.title)
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
                Task { await viewModel.load(movieID: movie.id) }
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

    // MARK: - Content

    private func detailContent(_ detail: TMDBMovieDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                posterHeader(detail)

                VStack(alignment: .leading, spacing: 20) {
                    titleBlock(detail)

                    if let trailer = detail.trailer {
                        watchTrailerButton(trailer)
                    }

                    actionButtons

                    if !detail.genres.isEmpty {
                        genreChips(detail.genres)
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

    private func posterHeader(_ detail: TMDBMovieDetail) -> some View {
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

    /// Floating play button on the poster: opens the trailer player.
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
        Image(systemName: "film")
            .font(.system(size: 48))
            .foregroundStyle(Theme.primary.opacity(0.4))
    }

    private func titleBlock(_ detail: TMDBMovieDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(detail.title)
                .font(.title.weight(.bold))
                .foregroundStyle(Theme.ink)

            HStack(spacing: 10) {
                if let year = detail.releaseYear {
                    metaBadge(icon: "calendar", text: year)
                }
                if let runtime = detail.formattedRuntime {
                    metaBadge(icon: "clock", text: runtime)
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
        }
    }

    // MARK: - Trailer

    /// Prominent "watch trailer" call to action.
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

    // MARK: - Watchlist / seen actions

    private var isInWatchlist: Bool { library.isInWatchlist(movie.id) }
    private var isSeen: Bool { library.isSeen(movie.id) }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            LibraryActionButton(
                title: isInWatchlist ? L("detail.inList") : L("detail.addList"),
                icon: isInWatchlist ? "bookmark.fill" : "bookmark",
                tint: Theme.primary,
                isActive: isInWatchlist
            ) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    library.toggleWatchlist(movie)
                }
            }

            LibraryActionButton(
                title: isSeen ? L("card.watched") : L("card.seen"),
                icon: isSeen ? "checkmark.circle.fill" : "checkmark.circle",
                tint: Theme.seenGreen,
                isActive: isSeen
            ) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    library.toggleSeen(movie)
                }
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: isInWatchlist)
        .sensoryFeedback(.success, trigger: isSeen)
    }

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

/// Prominent toggle button for watchlist / seen actions:
/// outlined when inactive, filled with its tint when active.
struct LibraryActionButton: View {
    let title: String
    let icon: String
    let tint: Color
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .contentTransition(.symbolEffect(.replace))
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(isActive ? .white : tint)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                isActive ? tint : tint.opacity(0.10),
                in: .rect(cornerRadius: 16)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(tint.opacity(isActive ? 0 : 0.35), lineWidth: 1.5)
            )
            .shadow(
                color: isActive ? tint.opacity(0.35) : .clear,
                radius: 10, y: 5
            )
        }
        .buttonStyle(PressableCardStyle())
    }
}

/// Small card with actor photo, name and role.
struct CastMemberCard: View {
    let member: TMDBCastMember

    var body: some View {
        VStack(spacing: 8) {
            Color(Theme.surface)
                .frame(width: 84, height: 84)
                .overlay {
                    if let url = member.profileURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .allowsHitTesting(false)
                            case .failure:
                                castFallback
                            default:
                                ProgressView()
                                    .tint(Theme.primary)
                            }
                        }
                    } else {
                        castFallback
                    }
                }
                .clipShape(.circle)
                .overlay(
                    Circle().stroke(Theme.primary.opacity(0.15), lineWidth: 1)
                )

            VStack(spacing: 2) {
                Text(member.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                if let character = member.character, !character.isEmpty {
                    Text(character)
                        .font(.caption2)
                        .foregroundStyle(Theme.inkSoft)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(width: 96)
    }

    private var castFallback: some View {
        Image(systemName: "person.fill")
            .font(.system(size: 28))
            .foregroundStyle(Theme.primary.opacity(0.4))
    }
}

#Preview {
    NavigationStack {
        MovieDetailView(
            movie: TMDBMovie(
                id: 603,
                title: "Matrix",
                overview: "Un hacker scopre la verità sulla realtà.",
                posterPath: nil,
                backdropPath: nil,
                releaseDate: "1999-03-31",
                voteAverage: 8.2,
                voteCount: 26000,
                genreIds: [28, 878]
            )
        )
    }
    .environment(MovieLibrary())
}
