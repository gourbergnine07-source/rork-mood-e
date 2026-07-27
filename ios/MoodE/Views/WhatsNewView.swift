//
//  WhatsNewView.swift
//  MoodE
//
//  "Novità" section: release notes for the latest update (iPad layout,
//  new privacy options, integrated cinema map, general polish).
//  Reached from Settings; a NEW badge on the row disappears once the
//  page has been opened for the current version.
//

import SwiftUI

/// Shared helper so the Settings row and this view agree on the
/// "has the user already seen the notes for this version?" state.
enum WhatsNew {
    static let lastSeenVersionKey = "whatsnew.lastSeenVersion"

    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}

/// Release-notes page: hero header with the version chip followed by
/// one card per highlight, entering with a soft staggered animation.
struct WhatsNewView: View {
    @AppStorage(WhatsNew.lastSeenVersionKey) private var lastSeenVersion: String = ""
    @State private var hasAppeared = false

    private struct Highlight: Identifiable {
        let id: String
        let icon: String
        let color: Color
        let titleKey: String
        let messageKey: String
    }

    private var highlights: [Highlight] {
        [
            Highlight(
                id: "ipad",
                icon: "ipad.landscape",
                color: Theme.tabHome,
                titleKey: "whatsnew.ipad.title",
                messageKey: "whatsnew.ipad.msg"
            ),
            Highlight(
                id: "privacy",
                icon: "hand.raised.fill",
                color: Theme.tabCinema,
                titleKey: "whatsnew.privacy.title",
                messageKey: "whatsnew.privacy.msg"
            ),
            Highlight(
                id: "map",
                icon: "map.fill",
                color: Theme.seenGreen,
                titleKey: "whatsnew.map.title",
                messageKey: "whatsnew.map.msg"
            ),
            Highlight(
                id: "polish",
                icon: "wand.and.stars",
                color: Theme.amber,
                titleKey: "whatsnew.polish.title",
                messageKey: "whatsnew.polish.msg"
            )
        ]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header

                VStack(spacing: 14) {
                    ForEach(Array(highlights.enumerated()), id: \.element.id) { index, highlight in
                        highlightCard(highlight)
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 18)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.85)
                                    .delay(0.08 + Double(index) * 0.07),
                                value: hasAppeared
                            )
                    }
                }

                Text(L("whatsnew.footer"))
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 40)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle(L("whatsnew.title"))
        .toolbarTitleDisplayMode(.inline)
        .onAppear {
            lastSeenVersion = WhatsNew.appVersion
            hasAppeared = true
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Theme.amber)
                .symbolEffect(.bounce, options: .nonRepeating, value: hasAppeared)
                .padding(.top, 12)
                .accessibilityHidden(true)

            Text(LF("whatsnew.version", WhatsNew.appVersion))
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.tabSettings)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Theme.tabSettings.opacity(0.12), in: .capsule)

            Text(L("whatsnew.intro"))
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func highlightCard(_ highlight: Highlight) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: highlight.icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(highlight.color, in: .rect(cornerRadius: 11))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(L(highlight.titleKey))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.ink)

                Text(L(highlight.messageKey))
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: .rect(cornerRadius: 18))
    }
}

#Preview {
    NavigationStack {
        WhatsNewView()
    }
}
