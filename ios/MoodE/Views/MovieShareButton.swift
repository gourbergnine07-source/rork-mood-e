//
//  MovieShareButton.swift
//  MoodE
//

import SwiftUI

/// Share button that opens the system share sheet with the movie's
/// title and key info. Two visual styles: a tinted chip for cards
/// and a dark circular overlay for posters.
struct MovieShareButton: View {
    let movieTitle: String
    let message: String
    var tint: Color = Theme.primary
    var style: Style = .chip

    enum Style {
        case chip
        case posterOverlay
    }

    var body: some View {
        ShareLink(item: message, subject: Text(movieTitle)) {
            label
        }
        .buttonStyle(.plain)
        .accessibilityLabel(LF("share.a11y", movieTitle))
    }

    @ViewBuilder
    private var label: some View {
        switch style {
        case .chip:
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.10), in: .circle)
                .overlay(
                    Circle().stroke(tint.opacity(0.35), lineWidth: 1)
                )
                .contentShape(.circle)

        case .posterOverlay:
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(.black.opacity(0.5), in: .circle)
                .background(.ultraThinMaterial, in: .circle)
                .overlay(
                    Circle().stroke(.white.opacity(0.55), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
                .contentShape(.circle)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        MovieShareButton(
            movieTitle: "Il film",
            message: "🎬 Il film (2024)\nhttps://www.themoviedb.org/movie/1"
        )
        MovieShareButton(
            movieTitle: "Il film",
            message: "🎬 Il film (2024)\nhttps://www.themoviedb.org/movie/1",
            style: .posterOverlay
        )
        .padding()
        .background(.black)
    }
    .padding()
}
