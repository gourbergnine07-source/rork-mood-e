//
//  SurpriseView.swift
//  MoodE
//

import SwiftUI

/// "Sorprendimi": slot-machine style random quality pick.
/// Three emoji reels spin while a high-rated movie is fetched, then the
/// result is revealed with a celebratory card.
struct SurpriseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(MovieLibrary.self) private var library

    private enum Phase {
        case spinning
        case revealed
        case failed
    }

    @State private var phase: Phase = .spinning
    @State private var movie: TMDBMovie?
    @State private var detailMovie: TMDBMovie?
    @State private var reelIndices: [Int] = [0, 2, 4]
    @State private var spinRound: Int = 0
    @State private var didReveal: Bool = false

    private static let symbols = ["🎬", "🍿", "🎞️", "⭐️", "🎥", "🎟️", "❤️", "😂"]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                switch phase {
                case .spinning:
                    spinningView
                case .revealed:
                    revealView
                case .failed:
                    failedView
                }
            }
            .navigationTitle(L("surprise.title"))
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("common.close")) { dismiss() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.primary)
                }
            }
            .navigationDestination(item: $detailMovie) { movie in
                MovieDetailView(movie: movie)
            }
        }
        .tint(Theme.primary)
        .task(id: spinRound) { await spin() }
        .sensoryFeedback(.impact(weight: .light), trigger: reelIndices)
        .sensoryFeedback(.success, trigger: didReveal)
    }

    // MARK: - Spinning

    private var spinningView: some View {
        VStack(spacing: 28) {
            reelsRow

            Text(L("surprise.spinning"))
                .font(.headline)
                .foregroundStyle(Theme.inkSoft)
        }
        .padding(.horizontal, 24)
    }

    private var reelsRow: some View {
        HStack(spacing: 14) {
            ForEach(0..<3, id: \.self) { reel in
                reelCard(reel)
            }
        }
    }

    private func reelCard(_ reel: Int) -> some View {
        ZStack {
            Text(Self.symbols[reelIndices[reel]])
                .font(.system(size: 46))
                .id(reelIndices[reel])
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
        }
        .frame(width: 88, height: 110)
        .background(Theme.card, in: .rect(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Theme.primary.opacity(0.15), lineWidth: 1)
        )
        .clipShape(.rect(cornerRadius: 22))
    }

    // MARK: - Reveal

    private var revealView: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text(L("surprise.reveal"))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.ink)

                if let movie {
                    Button {
                        detailMovie = movie
                    } label: {
                        posterCard(movie)
                    }
                    .buttonStyle(PressableCardStyle())
                    .accessibilityLabel(L("surprise.details"))

                    VStack(spacing: 6) {
                        Text(movie.title)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 10) {
                            if let year = movie.releaseYear {
                                Text(year)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.inkSoft)
                            }
                            if movie.voteAverage > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.amber)
                                    Text(LocalizationManager.shared.rating(movie.voteAverage))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Theme.ink)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    actionButtons(movie)
                }
            }
            .padding(.vertical, 24)
        }
        .scrollIndicators(.hidden)
        .transition(.scale(scale: 0.86).combined(with: .opacity))
    }

    private func posterCard(_ movie: TMDBMovie) -> some View {
        Color(Theme.surface)
            .frame(width: 210, height: 315)
            .overlay {
                if let url = movie.posterURL {
                    AsyncImage(url: url) { imagePhase in
                        switch imagePhase {
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
            .clipShape(.rect(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Theme.primary.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 18, y: 10)
    }

    private var posterFallback: some View {
        Image(systemName: "film")
            .font(.system(size: 40))
            .foregroundStyle(Theme.primary.opacity(0.4))
    }

    private func actionButtons(_ movie: TMDBMovie) -> some View {
        VStack(spacing: 10) {
            Button {
                detailMovie = movie
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                    Text(L("surprise.details"))
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Theme.primary, in: .rect(cornerRadius: 16))
            }
            .buttonStyle(PressableCardStyle())

            Button {
                spinRound += 1
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "dice.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text(L("surprise.again"))
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(Theme.rose)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Theme.rose.opacity(0.12), in: .rect(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Theme.rose.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(PressableCardStyle())
        }
        .padding(.horizontal, 32)
        .padding(.top, 4)
    }

    // MARK: - Failure

    private var failedView: some View {
        VStack(spacing: 18) {
            Text("🎰")
                .font(.system(size: 52))
            Text(L("surprise.error"))
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
            Button {
                spinRound += 1
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

    // MARK: - Spin logic

    /// Runs the reels for ~1.8s (slowing down towards the end) while the
    /// random movie is fetched, then reveals the result.
    private func spin() async {
        withAnimation(.easeInOut(duration: 0.25)) { phase = .spinning }
        movie = nil

        let watched = library.watchedIds
        let recentlyShown = RecommendationRegistry.shared.recentlyShownIds().subtracting(watched)
        let fetch = Task {
            try? await TMDBService.surpriseMovie(excluding: watched, avoiding: recentlyShown)
        }

        let start = Date()
        var interval = 80
        while Date().timeIntervalSince(start) < 1.8, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(interval))
            withAnimation(.easeOut(duration: 0.12)) {
                for index in reelIndices.indices {
                    reelIndices[index] = (reelIndices[index] + 1 + index) % Self.symbols.count
                }
            }
            if Date().timeIntervalSince(start) > 1.1 {
                interval = min(interval + 30, 240)
            }
        }

        guard !Task.isCancelled else { return }
        let result = await fetch.value

        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
            if let result {
                movie = result
                phase = .revealed
                didReveal.toggle()
            } else {
                phase = .failed
            }
        }

        // Track the pick so it won't come back for 7 days (here or in the flow).
        if let result {
            RecommendationRegistry.shared.registerSurprise(result)
        }

        // Auto-open the movie detail shortly after the reveal so the user
        // doesn't have to look for it. Going back returns to the reveal card.
        guard let revealed = result, phase == .revealed else { return }
        try? await Task.sleep(for: .seconds(1.2))
        guard !Task.isCancelled, phase == .revealed, detailMovie == nil else { return }
        detailMovie = revealed
    }
}

#Preview {
    SurpriseView()
        .environment(MovieLibrary())
}
