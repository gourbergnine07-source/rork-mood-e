//
//  SettingsView.swift
//  MoodE
//

import SwiftUI

/// Central place for the GitHub-based support & legal URLs.
enum AppLinks {
    /// GitHub username.
    static let gitHubUser = "gourbergnine07-source"
    /// Repository name.
    static let gitHubRepo = "rork-mood-e"

    /// True once the real GitHub username/repo have been filled in.
    /// While false, legal pages are served from the app bundle.
    static var isRemoteConfigured: Bool {
        gitHubUser != "tuo-username-github" && gitHubRepo != "nome-repo"
    }

    static var privacyPolicy: URL {
        URL(string: "https://\(gitHubUser).github.io/\(gitHubRepo)/privacy-policy.html")!
    }
    static var terms: URL {
        URL(string: "https://\(gitHubUser).github.io/\(gitHubRepo)/termini.html")!
    }
    static var newIssue: URL {
        URL(string: "https://github.com/\(gitHubUser)/\(gitHubRepo)/issues/new")!
    }
    static var issuesList: URL {
        URL(string: "https://github.com/\(gitHubUser)/\(gitHubRepo)/issues")!
    }
}

/// Impostazioni tab: app info, privacy, support and legal sections
/// in a classic iOS grouped list.
struct SettingsView: View {
    @Environment(\.openURL) private var openURL

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return version
    }

    var body: some View {
        NavigationStack {
            List {
                appInfoSection
                privacySection
                supportSection
                legalSection
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Impostazioni")
            .toolbarTitleDisplayMode(.large)
            .navigationDestination(for: LegalPage.self) { page in
                LegalPageView(page: page)
            }
        }
        .tint(Theme.tabSettings)
    }

    // MARK: - Info app

    private var appInfoSection: some View {
        Section("Info app") {
            HStack(spacing: 16) {
                Image("film_strip_heart_gold")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 64, height: 64)
                    .clipShape(.rect(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Theme.ink.opacity(0.08), lineWidth: 1)
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Mood-E")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text("v\(appVersion)")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                    Text("Il film giusto per ogni emozione")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .padding(.vertical, 6)
        }
        .listRowBackground(Theme.card)
    }

    // MARK: - Privacy

    private var privacySection: some View {
        Section("Privacy") {
            NavigationLink(value: LegalPage.privacyPolicy) {
                SettingsRow(
                    icon: "hand.raised.fill",
                    iconColor: Theme.tabCinema,
                    title: "Informativa sulla Privacy"
                )
            }
        }
        .listRowBackground(Theme.card)
    }

    // MARK: - Supporto e assistenza

    private var supportSection: some View {
        Section {
            Button {
                openURL(AppLinks.newIssue)
            } label: {
                SettingsRow(
                    icon: "exclamationmark.bubble.fill",
                    iconColor: Theme.primary,
                    title: "Segnala un problema",
                    showsExternalBadge: true
                )
            }

            Button {
                openURL(AppLinks.issuesList)
            } label: {
                SettingsRow(
                    icon: "questionmark.circle.fill",
                    iconColor: Theme.amber,
                    title: "Domande frequenti / Issues esistenti",
                    showsExternalBadge: true
                )
            }
        } header: {
            Text("Supporto e assistenza")
        } footer: {
            Text("Per segnalare un problema o richiedere una nuova funzione, apri una richiesta sul nostro GitHub. Ti risponderemo il prima possibile.")
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
        }
        .listRowBackground(Theme.card)
    }

    // MARK: - Legale

    private var legalSection: some View {
        Section {
            NavigationLink(value: LegalPage.terms) {
                SettingsRow(
                    icon: "doc.text.fill",
                    iconColor: Theme.tabList,
                    title: "Termini di utilizzo"
                )
            }
        } header: {
            Text("Legale")
        } footer: {
            Text("Questa app utilizza dati forniti da TMDB ma non è approvata o certificata da TMDB.")
                .font(.caption2)
                .foregroundStyle(Theme.inkSoft)
        }
        .listRowBackground(Theme.card)
    }
}

/// Single settings row: rounded icon tile + title, classic iOS style.
struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var showsExternalBadge: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 29, height: 29)
                .background(iconColor, in: .rect(cornerRadius: 7))

            Text(title)
                .font(.body)
                .foregroundStyle(Theme.ink)

            Spacer(minLength: 0)

            if showsExternalBadge {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.inkSoft.opacity(0.7))
                    .accessibilityLabel("Si apre nel browser")
            }
        }
        .contentShape(.rect)
    }
}

#Preview {
    SettingsView()
}
