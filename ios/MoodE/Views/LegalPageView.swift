//
//  LegalPageView.swift
//  MoodE
//

import SwiftUI
import WebKit

/// Legal pages opened inside the app via an embedded WebView.
enum LegalPage: Hashable {
    case privacyPolicy
    case terms

    var title: String {
        switch self {
        case .privacyPolicy: return "Informativa sulla Privacy"
        case .terms: return "Termini di utilizzo"
        }
    }

    var remoteURL: URL {
        switch self {
        case .privacyPolicy: return AppLinks.privacyPolicy
        case .terms: return AppLinks.terms
        }
    }

    /// HTML file bundled with the app, shown until GitHub Pages is live.
    var bundledFileName: String {
        switch self {
        case .privacyPolicy: return "privacy-policy"
        case .terms: return "termini"
        }
    }

    var bundledURL: URL? {
        Bundle.main.url(forResource: bundledFileName, withExtension: "html")
    }

    /// Remote page when configured, otherwise the local copy in the bundle.
    var resolvedURL: URL? {
        AppLinks.isRemoteConfigured ? remoteURL : bundledURL
    }
}

/// In-app web page with a custom "Indietro" header — the user never leaves the app.
struct LegalPageView: View {
    let page: LegalPage

    @Environment(\.dismiss) private var dismiss
    @State private var loadState: WebPageLoadState = .loading
    @State private var reloadToken: Int = 0

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if let url = page.resolvedURL {
                WebPageView(url: url, loadState: $loadState)
                    .id(reloadToken)
                    .opacity(loadState == .loaded ? 1 : 0)
            }

            switch loadState {
            case .loading:
                VStack(spacing: 14) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(Theme.tabSettings)
                    Text("Carico la pagina…")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                }
            case .failed:
                failedView
            case .loaded:
                EmptyView()
            }
        }
        .navigationTitle(page.title)
        .toolbarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Indietro")
                    }
                }
                .accessibilityLabel("Torna alle Impostazioni")
            }
        }
    }

    private var failedView: some View {
        VStack(spacing: 18) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(Theme.tabSettings)
            Text("Pagina non disponibile")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text("Non è stato possibile caricare la pagina. Controlla la connessione e riprova.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
            Button {
                loadState = .loading
                reloadToken += 1
            } label: {
                Label("Riprova", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Theme.tabSettings, in: .capsule)
            }
        }
        .padding(.horizontal, 32)
    }
}

/// Load state for the embedded web page.
enum WebPageLoadState {
    case loading
    case loaded
    case failed
}

/// WKWebView wrapper that reports its load state back to SwiftUI.
struct WebPageView: UIViewRepresentable {
    let url: URL
    @Binding var loadState: WebPageLoadState

    func makeCoordinator() -> Coordinator {
        Coordinator(loadState: $loadState)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        if url.isFileURL {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let loadState: Binding<WebPageLoadState>

        init(loadState: Binding<WebPageLoadState>) {
            self.loadState = loadState
        }

        nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in
                loadState.wrappedValue = .loaded
            }
        }

        nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in
                loadState.wrappedValue = .failed
            }
        }

        nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in
                loadState.wrappedValue = .failed
            }
        }
    }
}
