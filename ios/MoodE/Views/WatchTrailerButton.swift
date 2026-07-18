//
//  WatchTrailerButton.swift
//  MoodE
//

import SwiftUI

/// Shared trailer playback state: fetches the best trailer for a movie
/// and drives the in-app player sheet without leaving the app.
@Observable
final class TrailerPlayback {
    var selection: TrailerSelection?
    var loadingMovieId: Int?
    var showsUnavailable = false

    /// Fetches the best trailer for the movie and opens the player sheet.
    func play(_ movie: TMDBMovie) {
        guard loadingMovieId == nil else { return }
        loadingMovieId = movie.id
        Task {
            defer { loadingMovieId = nil }
            do {
                let videos = try await TMDBService.movieVideos(id: movie.id)
                if let trailer = videos.bestTrailer {
                    selection = TrailerSelection(movieTitle: movie.title, trailer: trailer)
                } else {
                    showsUnavailable = true
                }
            } catch {
                showsUnavailable = true
            }
        }
    }
}

extension View {
    /// Attaches the in-app trailer player sheet and the "unavailable" alert
    /// driven by a `TrailerPlayback` instance.
    func trailerPlayer(_ playback: TrailerPlayback) -> some View {
        modifier(TrailerPlayerModifier(playback: playback))
    }
}

private struct TrailerPlayerModifier: ViewModifier {
    @Bindable var playback: TrailerPlayback

    func body(content: Content) -> some View {
        content
            .sheet(item: $playback.selection) { selection in
                TrailerPlayerSheet(trailer: selection.trailer, movieTitle: selection.movieTitle)
            }
            .alert(L("trailer.unavailable.title"), isPresented: $playback.showsUnavailable) {
                Button(L("common.ok"), role: .cancel) {}
            } message: {
                Text(L("trailer.unavailable.msg"))
            }
    }
}

/// "Guarda Trailer" button shown on movie cards. Opens the in-app
/// trailer player without leaving the app.
struct WatchTrailerButton: View {
    var tint: Color = Theme.primary
    var isCompact: Bool = false
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: isCompact ? 4 : 6) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .controlSize(.mini)
                } else {
                    Image(systemName: "play.fill")
                        .font(.system(size: isCompact ? 10 : 12, weight: .bold))
                }
                Text(L("trailer.watch"))
                    .font(isCompact ? .caption2.weight(.bold) : .caption.weight(.bold))
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, isCompact ? 10 : 13)
            .frame(height: isCompact ? 26 : 32)
            .background(
                isLoading ? tint.opacity(0.6) : tint,
                in: .capsule
            )
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .accessibilityLabel(L("trailer.watchLong"))
    }
}

#Preview {
    VStack(spacing: 16) {
        WatchTrailerButton(action: {})
        WatchTrailerButton(tint: Theme.tabCinema, isCompact: true, action: {})
        WatchTrailerButton(isLoading: true, action: {})
    }
    .padding()
    .background(Theme.background)
}
