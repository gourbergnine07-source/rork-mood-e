//
//  MovieDetailView.swift
//  MoodE
//

import SwiftUI

/// Detail screen: enlarged poster, runtime, main cast and official trailer.
struct MovieDetailView: View {
    let movie: TMDBMovie

    @State private var viewModel = MovieDetailViewModel()

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
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(Theme.primary)
            Text("Carico i dettagli…")
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
                Task { await viewModel.load(movieID: movie.id) }
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

    // MARK: - Content

    private func detailContent(_ detail: TMDBMovieDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                posterHeader(detail)

                VStack(alignment: .leading, spacing: 20) {
                    titleBlock(detail)

                    if !detail.genres.isEmpty {
                        genreChips(detail.genres)
                    }

                    if !detail.overview.isEmpty {
                        overviewSection(detail.overview)
                    }

                    if let trailer = detail.trailer, let embedURL = trailer.embedURL {
                        trailerSection(embedURL)
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
                    Text(String(format: "%.1f", detail.voteAverage))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.amber.opacity(0.15), in: .capsule)
            }
        }
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
        .background(.white.opacity(0.65), in: .capsule)
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
            sectionTitle("Trama")
            Text(overview)
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .lineSpacing(4)
        }
    }

    private func trailerSection(_ embedURL: URL) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Trailer ufficiale")
            TrailerWebView(url: embedURL)
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Theme.primary.opacity(0.10), lineWidth: 1)
                )
        }
    }

    private func castSection(_ cast: [TMDBCastMember]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Cast principale")

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
}
