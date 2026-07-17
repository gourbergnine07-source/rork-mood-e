//
//  TrailerWebView.swift
//  MoodE
//

import SwiftUI
import WebKit

/// Embedded YouTube player for official trailers.
struct TrailerWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url == nil {
            webView.load(URLRequest(url: url))
        }
    }
}

/// Cinematic sheet presenting the trailer in a large embedded player.
struct TrailerPlayerSheet: View {
    let trailer: TMDBVideo
    let movieTitle: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                Spacer()

                if let url = trailer.autoplayEmbedURL ?? trailer.embedURL {
                    TrailerWebView(url: url)
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .clipShape(.rect(cornerRadius: 14))
                        .padding(.horizontal, 12)
                } else {
                    unavailableView
                }

                Spacer()
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(movieTitle)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(trailer.name)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .accessibilityLabel("Chiudi trailer")
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
    }

    private var unavailableView: some View {
        VStack(spacing: 12) {
            Image(systemName: "play.slash")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.5))
            Text("Trailer non disponibile")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}
