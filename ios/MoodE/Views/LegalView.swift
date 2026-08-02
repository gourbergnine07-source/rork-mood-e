//
//  LegalView.swift
//  MoodE
//

import SwiftUI

/// Route to the legal hub, registered at the Settings stack root.
enum LegalRoute: Hashable {
    case hub
}

/// Legal hub: one screen gathering direct links to the privacy policy,
/// the terms of use and the technical support page. Every document opens
/// inside the app (`LegalPageView`) and can also be opened in the browser.
struct LegalView: View {
    @Environment(\.openURL) private var openURL

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header

                VStack(spacing: 12) {
                    documentCard(
                        page: .privacyPolicy,
                        icon: "hand.raised.fill",
                        tint: Theme.tabCinema,
                        subtitle: L("legalhub.privacy.desc")
                    )
                    documentCard(
                        page: .terms,
                        icon: "doc.text.fill",
                        tint: Theme.tabList,
                        subtitle: L("legalhub.terms.desc")
                    )
                    documentCard(
                        page: .support,
                        icon: "lifepreserver.fill",
                        tint: Theme.primary,
                        subtitle: L("legalhub.support.desc")
                    )
                }

                webCard
                footer
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(L("legalhub.title"))
        .toolbarTitleDisplayMode(.inline)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 38))
                .foregroundStyle(Theme.tabSettings)
                .padding(.top, 12)

            Text(L("legalhub.headline"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)

            Text(L("legalhub.subtitle"))
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 4)
    }

    private func documentCard(
        page: LegalPage,
        icon: String,
        tint: Color,
        subtitle: String
    ) -> some View {
        NavigationLink(value: page) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(tint, in: .rect(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text(page.title)
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft.opacity(0.6))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: .rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityHint(subtitle)
    }

    private var webCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("legalhub.web.header"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.inkSoft)
                .textCase(.uppercase)

            Button {
                openURL(AppLinks.website)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "safari.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text(L("legalhub.web.open"))
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(Theme.tabSettings)
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(Theme.card, in: .rect(cornerRadius: 14))
            }
            .buttonStyle(.plain)

            Text(L("legalhub.web.footer"))
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
        }
        .padding(.top, 8)
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Text(LF("legalhub.version", appVersion))
                .font(.caption2)
                .foregroundStyle(Theme.inkSoft)
            Text(L("settings.legal.footer"))
                .font(.caption2)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 18)
    }
}
