//
//  FeaturedCollectionView.swift
//  MoodE
//

import SwiftUI

/// Movie list of one editorial collection ("In evidenza" card tap).
struct FeaturedCollectionView: View {
    let collection: FeaturedCollection

    @State private var state: LoadState = .loading
    @State private var trailerPlayback = TrailerPlayback()

    private enum LoadState {
        case loading
        case failed(String)
        case loaded([TMDBMovie])
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            switch state {
            case .loading:
                loadingView
            case .failed(let message):
                errorView(message)
            case .loaded(let movies):
                if movies.isEmpty {
                    emptyView
                } else {
                    moviesList(movies)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AdBannerView()
        }
        .navigationTitle(collection.title)
        .toolbarTitleDisplayMode(.inline)
        .tint(Theme.primary)
        .navigationDestination(for: TMDBMovie.self) { movie in
            MovieDetailView(movie: movie)
        }
        .task {
            await load()
        }
        .onChange(of: LocalizationManager.shared.language) { _, _ in
            Task { await load() }
        }
        .trailerPlayer(trailerPlayback)
    }

    // MARK: - States

    private var loadingView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
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
                Task { await load() }
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
            Text(L("results.empty.msg"))
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - List

    private func moviesList(_ movies: [TMDBMovie]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                LazyVStack(spacing: 14) {
                    ForEach(movies) { movie in
                        NavigationLink(value: movie) {
                            MovieCard(
                                movie: movie,
                                isLoadingTrailer: trailerPlayback.loadingMovieId == movie.id,
                                onPlayTrailer: { trailerPlayback.play(movie) }
                            )
                        }
                        .buttonStyle(PressableCardStyle())
                    }
                }
                .sensoryFeedback(.impact(weight: .medium), trigger: trailerPlayback.loadingMovieId)
                .padding(.horizontal, 24)
            }
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
    }

    /// Compact gradient banner echoing the tapped card.
    private var header: some View {
        HStack(spacing: 12) {
            if EmojiSupport.isAvailable {
                Text(collection.emoji)
                    .font(.system(size: 30))
            } else {
                Image(systemName: collection.icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text(collection.subtitle)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: collection.gradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: 18)
        )
        .padding(.horizontal, 24)
    }

    private func load() async {
        state = .loading
        do {
            let movies = try await TMDBService.featuredMovies(source: collection.source)
            state = .loaded(movies)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

#Preview {
    NavigationStack {
        FeaturedCollectionView(collection: FeaturedCalendar.all[5])
    }
    .environment(MovieLibrary())
    .environment(MoodDiary())
}
