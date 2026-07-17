//
//  MovieResultsView.swift
//  MoodE
//

import SwiftUI

/// Results screen: shows TMDB movies matching the user's mood flow choices.
struct MovieResultsView: View {
    let selection: MoodSelection

    @State private var viewModel = MovieResultsViewModel()
    @Environment(MovieLibrary.self) private var library

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
        .navigationTitle("Il tuo film")
        .toolbarTitleDisplayMode(.inline)
        .tint(Theme.primary)
        .navigationDestination(for: TMDBMovie.self) { movie in
            MovieDetailView(movie: movie)
        }
        .task {
            await viewModel.load(selection: selection, excluding: library.watchedIds)
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(Theme.primary)
            Text("Sto cercando il film perfetto per te…")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(Theme.primary)
            Text("Ops!")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
            Button {
                Task { await viewModel.load(selection: selection, excluding: library.watchedIds) }
            } label: {
                Label("Riprova", systemImage: "arrow.clockwise")
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
            Text("Nessun film trovato")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text("Prova a cambiare epoca o obiettivo: con scelte diverse troveremo sicuramente qualcosa.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
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

                    Text("Scelti per te")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 24)

                    LazyVStack(spacing: 14) {
                        ForEach(movies) { movie in
                            NavigationLink(value: movie) {
                                MovieCard(movie: movie)
                            }
                            .buttonStyle(PressableCardStyle())
                        }
                    }
                    .padding(.horizontal, 24)

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
                Text("Nuove proposte")
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
                recapChip(emoji: selection.era.emoji, text: selection.era.title)
            }
        }
        .contentMargins(.horizontal, 24)
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
        .background(.white.opacity(0.65), in: .capsule)
        .overlay(
            Capsule().stroke(Theme.primary.opacity(0.15), lineWidth: 1)
        )
    }
}

/// Card showing a single movie with poster, rating and overview.
struct MovieCard: View {
    let movie: TMDBMovie

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            poster

            VStack(alignment: .leading, spacing: 6) {
                Text(movie.title)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)

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
                        Text(String(format: "%.1f", movie.voteAverage))
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
                        .lineLimit(4)
                        .lineSpacing(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.white.opacity(0.65), in: .rect(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Theme.primary.opacity(0.10), lineWidth: 1)
        )
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
    }

    private var posterFallback: some View {
        Image(systemName: "film")
            .font(.system(size: 26))
            .foregroundStyle(Theme.primary.opacity(0.4))
    }
}

#Preview {
    NavigationStack {
        MovieResultsView(
            selection: MoodSelection(mood: .felice, goal: .ridere, era: .nineties)
        )
    }
    .environment(MovieLibrary())
}
