//
//  LegalPageView.swift
//  MoodE
//

import SwiftUI
import UIKit
import WebKit

/// Legal pages opened inside the app via an embedded WebView.
enum LegalPage: Hashable {
    case privacyPolicy
    case terms

    var title: String {
        switch self {
        case .privacyPolicy: return L("legal.privacy")
        case .terms: return L("legal.terms")
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
    /// True after the remote page failed (network error or HTTP 4xx/5xx):
    /// the bundled copy is shown instead, so the user always sees the text.
    @State private var useBundled = false

    private var currentURL: URL? {
        useBundled ? page.bundledURL : page.resolvedURL
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if let url = currentURL {
                WebPageView(url: url, loadState: $loadState)
                    .id("\(useBundled)-\(reloadToken)")
                    .opacity(loadState == .loaded ? 1 : 0)
            }

            switch loadState {
            case .loading:
                VStack(spacing: 14) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(Theme.tabSettings)
                    Text(L("legal.loading"))
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                }
            case .failed:
                failedView
            case .loaded:
                EmptyView()
            }
        }
        .onChange(of: loadState) { _, newValue in
            // Remote page unreachable or missing: fall back to the copy
            // bundled with the app instead of showing an error page.
            if newValue == .failed, !useBundled, page.bundledURL != nil {
                useBundled = true
                loadState = .loading
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
                        Text(L("legal.back"))
                    }
                }
                .accessibilityLabel(L("legal.a11y.back"))
            }
        }
    }

    private var failedView: some View {
        VStack(spacing: 18) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(Theme.tabSettings)
            Text(L("legal.failed.title"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text(L("legal.failed.msg"))
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
            Button {
                useBundled = false
                loadState = .loading
                reloadToken += 1
            } label: {
                Label(L("common.retry"), systemImage: "arrow.clockwise")
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

        /// Links tapped inside the page (e.g. the GitHub contact link) open
        /// in the external browser: the WebView only renders the legal text
        /// itself. Without this, taps on links in a locally bundled page are
        /// silently blocked (file→https navigation) and nothing happens.
        nonisolated func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url,
                  url.scheme == "https" || url.scheme == "http" || url.scheme == "mailto" else {
                return .allow
            }
            await MainActor.run {
                UIApplication.shared.open(url)
            }
            return .cancel
        }

        /// Treats HTTP error responses (404, 500, ...) as failures: without
        /// this check a "page not found" page would render as a success.
        nonisolated func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationResponse: WKNavigationResponse
        ) async -> WKNavigationResponsePolicy {
            if let http = navigationResponse.response as? HTTPURLResponse, http.statusCode >= 400 {
                Task { @MainActor in
                    loadState.wrappedValue = .failed
                }
                return .cancel
            }
            return .allow
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
