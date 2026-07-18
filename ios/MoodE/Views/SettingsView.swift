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
    @Environment(NotificationService.self) private var notifications
    @Environment(MovieLibrary.self) private var library
    @State private var showPermissionAlert = false
    private var theme: ThemeManager { ThemeManager.shared }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return version
    }

    var body: some View {
        NavigationStack {
            List {
                appInfoSection
                appearanceSection
                notificationsSection
                librarySection
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
            .alert("Notifiche disattivate", isPresented: $showPermissionAlert) {
                Button("Apri Impostazioni") { openSystemSettings() }
                Button("Annulla", role: .cancel) {}
            } message: {
                Text("Per ricevere gli avvisi sulle nuove uscite, consenti le notifiche di Mood-E nelle impostazioni di iOS.")
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

    // MARK: - Aspetto

    private var appearanceModeBinding: Binding<AppearanceMode> {
        Binding(
            get: { theme.appearance },
            set: { newValue in
                withAnimation(.easeInOut(duration: 0.3)) {
                    theme.appearance = newValue
                }
            }
        )
    }

    private var appearanceSection: some View {
        Section {
            Picker(selection: appearanceModeBinding) {
                ForEach(AppearanceMode.allCases) { mode in
                    Label(mode.displayName, systemImage: mode.icon)
                        .tag(mode)
                }
            } label: {
                SettingsRow(
                    icon: "circle.lefthalf.filled",
                    iconColor: Theme.tabCinema,
                    title: "Tema"
                )
            }
            .pickerStyle(.menu)
            .sensoryFeedback(.selection, trigger: theme.appearance)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 16) {
                ForEach(AccentPalette.allCases) { palette in
                    PaletteSwatchButton(
                        palette: palette,
                        isSelected: theme.accent == palette
                    ) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            theme.accent = palette
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .sensoryFeedback(.selection, trigger: theme.accent)
        } header: {
            Text("Aspetto")
        } footer: {
            Text("Con \"Sistema\" l'app segue la modalità chiara o scura di iOS, oppure puoi forzarla. La palette cambia il colore principale e lo sfondo di tutta l'app.")
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
        }
        .listRowBackground(Theme.card)
    }

    // MARK: - Notifiche

    private var notificationsBinding: Binding<Bool> {
        Binding(
            get: { notifications.isEnabled },
            set: { newValue in
                Task {
                    let success = await notifications.setEnabled(newValue)
                    if newValue && !success {
                        showPermissionAlert = true
                    }
                }
            }
        )
    }

    private var notificationsSection: some View {
        Section {
            Toggle(isOn: notificationsBinding) {
                SettingsRow(
                    icon: "bell.badge.fill",
                    iconColor: Theme.rose,
                    title: "Nuove uscite e film al cinema"
                )
            }
            .tint(Theme.tabSettings)
            .disabled(notifications.isWorking)

            if notifications.authorizationStatus == .denied {
                Button {
                    openSystemSettings()
                } label: {
                    SettingsRow(
                        icon: "gear.badge.xmark",
                        iconColor: Theme.inkSoft,
                        title: "Consenti le notifiche in iOS",
                        showsExternalBadge: true
                    )
                }
            }
        } header: {
            Text("Notifiche")
        } footer: {
            Text("Ricevi un avviso quando arrivano nuovi film su TMDB e il giorno in cui un film esce al cinema. Puoi disattivarle quando vuoi.")
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
        }
        .listRowBackground(Theme.card)
    }

    // MARK: - La mia lista

    private var autoRemoveBinding: Binding<Bool> {
        Binding(
            get: { library.autoRemoveWatchedAfterWeek },
            set: { library.autoRemoveWatchedAfterWeek = $0 }
        )
    }

    private var librarySection: some View {
        Section {
            Toggle(isOn: autoRemoveBinding) {
                SettingsRow(
                    icon: "clock.arrow.circlepath",
                    iconColor: Theme.seenGreen,
                    title: "Rimuovi i visti dopo 7 giorni"
                )
            }
            .tint(Theme.tabSettings)
        } header: {
            Text("La mia lista")
        } footer: {
            Text("I film segnati come \"già visti\" vengono rimossi automaticamente dopo una settimana. Una volta rimossi, potranno riapparire tra i consigli. Puoi sempre rimuoverli manualmente dalla lista.")
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
        }
        .listRowBackground(Theme.card)
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
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

            NavigationLink {
                FAQView()
            } label: {
                SettingsRow(
                    icon: "questionmark.circle.fill",
                    iconColor: Theme.amber,
                    title: "Domande frequenti"
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

/// Tappable color swatch for the appearance picker: a filled circle
/// with a selection ring and the palette name underneath.
struct PaletteSwatchButton: View {
    let palette: AccentPalette
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(palette.swatch)
                        .frame(width: 40, height: 40)

                    if isSelected {
                        Circle()
                            .strokeBorder(palette.swatch, lineWidth: 2.5)
                            .frame(width: 52, height: 52)
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.inkInverse)
                    }
                }
                .frame(width: 52, height: 52)

                Text(palette.displayName)
                    .font(.caption2.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Theme.ink : Theme.inkSoft)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Palette \(palette.displayName)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
        .environment(NotificationService())
        .environment(MovieLibrary())
}
