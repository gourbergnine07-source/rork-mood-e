//
//  TrailerWebView.swift
//  MoodE
//

import SwiftUI
import WebKit

/// Embedded YouTube player for official trailers.
///
/// Loads the embed inside an HTML page with a valid https baseURL so the
/// request carries a proper referer/origin — without it YouTube rejects the
/// player with "Error 153: video player configuration error".
struct TrailerWebView: UIViewRepresentable {
    let videoKey: String
    var autoplay: Bool = false

    /// Origin sent to the YouTube iframe player; must be a real https page.
    private static let embedOrigin = "https://rork.app"

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.loadHTMLString(embedHTML, baseURL: URL(string: Self.embedOrigin))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    private var embedHTML: String {
        let autoplayValue = autoplay ? "1" : "0"
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>
        html, body { margin: 0; padding: 0; background: #000; height: 100%; overflow: hidden; }
        iframe { position: absolute; inset: 0; width: 100%; height: 100%; border: 0; }
        </style>
        </head>
        <body>
        <iframe
            src="https://www.youtube.com/embed/\(videoKey)?playsinline=1&rel=0&autoplay=\(autoplayValue)&origin=\(Self.embedOrigin)"
            allow="autoplay; encrypted-media; fullscreen; picture-in-picture"
            allowfullscreen>
        </iframe>
        </body>
        </html>
        """
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

                TrailerWebView(videoKey: trailer.key, autoplay: true)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 14))
                    .padding(.horizontal, 12)

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
            .accessibilityLabel(L("trailer.close"))
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
    }

    private var unavailableView: some View {
        VStack(spacing: 12) {
            Image(systemName: "play.slash")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.5))
            Text(L("trailer.unavailable.title"))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}
