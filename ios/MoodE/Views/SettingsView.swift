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
    @Environment(MoodDiary.self) private var diary
    @State private var showPermissionAlert = false
    @State private var showOnboarding = false
    @AppStorage("onboarding.completed") private var hasCompletedOnboarding: Bool = true
    private var theme: ThemeManager { ThemeManager.shared }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return version
    }

    var body: some View {
        NavigationStack {
            List {
                appInfoSection
                journeySection
                appearanceSection
                languageSection
                notificationsSection
                librarySection
                onboardingSection
                adsSection
                privacySection
                supportSection
                legalSection
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle(L("tab.settings"))
            .toolbarTitleDisplayMode(.large)
            .navigationDestination(for: LegalPage.self) { page in
                LegalPageView(page: page)
            }
            .navigationDestination(for: DiaryRoute.self) { route in
                switch route {
                case .badges: BadgesView()
                case .memories: MemoriesView()
                }
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView {
                    hasCompletedOnboarding = true
                    showOnboarding = false
                }
            }
            .alert(L("settings.notif.alert.title"), isPresented: $showPermissionAlert) {
                Button(L("settings.notif.open")) { openSystemSettings() }
                Button(L("common.cancel"), role: .cancel) {}
            } message: {
                Text(L("settings.notif.alert.msg"))
            }
        }
        .tint(Theme.tabSettings)
    }

    // MARK: - Pubblicità

    private var adsSection: some View {
        Section {
            Button {
                openSystemSettings()
            } label: {
                SettingsRow(
                    icon: "megaphone.fill",
                    iconColor: Theme.primary,
                    title: L("settings.ads.consent"),
                    showsExternalBadge: true
                )
            }
        } header: {
            Text(L("settings.ads.header"))
        } footer: {
            Text(L("settings.ads.footer"))
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
        }
        .listRowBackground(Theme.card)
    }

    // MARK: - Info app

    private var appInfoSection: some View {
        Section(L("settings.info")) {
            HStack(spacing: 16) {
                Image("app_icon_preview")
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
                    Text(L("app.tagline"))
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
                    title: L("settings.theme")
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
            Text(L("settings.appearance"))
        } footer: {
            Text(L("settings.appearance.footer"))
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
        }
        .listRowBackground(Theme.card)
    }

    // MARK: - Lingua

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { LocalizationManager.shared.language },
            set: { newValue in
                withAnimation(.easeInOut(duration: 0.25)) {
                    LocalizationManager.shared.language = newValue
                }
            }
        )
    }

    private var languageSection: some View {
        Section {
            Picker(selection: languageBinding) {
                ForEach(AppLanguage.allCases) { language in
                    Text("\(language.flag)  \(language.nativeName)").tag(language)
                }
            } label: {
                SettingsRow(
                    icon: "globe",
                    iconColor: Theme.tabHome,
                    title: L("settings.language")
                )
            }
            .pickerStyle(.menu)
            .sensoryFeedback(.selection, trigger: LocalizationManager.shared.language)
        } header: {
            Text(L("settings.language.header"))
        } footer: {
            Text(L("settings.language.footer"))
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
        }
        .listRowBackground(Theme.card)
    }

    // MARK: - Il mio percorso

    private var journeySection: some View {
        Section {
            HStack(spacing: 12) {
            Text("\u{1F525}")
                    .font(.system(size: 20))
                    .frame(width: 29, height: 29)
                VStack(alignment: .leading, spacing: 1) {
                    Text(L("settings.journey.streak"))
                        .font(.body)
                        .foregroundStyle(Theme.ink)
                    if diary.streak == 0 {
                        Text(L("diary.streak.broken.msg"))
                            .font(.caption2)
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                Spacer()
                Text(diary.streak > 0 ? LF("diary.streak.days", diary.streak) : "—")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.inkSoft)
            }

            NavigationLink(value: DiaryRoute.badges) {
                SettingsRow(
                    icon: "rosette",
                    iconColor: Theme.amber,
                    title: L("settings.journey.badges")
                )
            }
        } header: {
            Text(L("settings.journey.header"))
        } footer: {
            Text(L("settings.journey.footer"))
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
                    } else if newValue {
                        await notifications.refreshSchedules(
                            toWatch: library.toWatch,
                            topGenres: diary.topGenreIds
                        )
                    }
                }
            }
        )
    }

    private var eveningBinding: Binding<Bool> {
        Binding(
            get: { notifications.eveningEnabled },
            set: { notifications.setEveningEnabled($0) }
        )
    }

    private var eveningTimeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: notifications.eveningHour,
                    minute: notifications.eveningMinute,
                    second: 0,
                    of: Date()
                ) ?? Date()
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                notifications.setEveningTime(
                    hour: components.hour ?? 20,
                    minute: components.minute ?? 0
                )
            }
        )
    }

    private var watchlistNotifBinding: Binding<Bool> {
        Binding(
            get: { notifications.watchlistEnabled },
            set: { notifications.setWatchlistEnabled($0, toWatch: library.toWatch) }
        )
    }

    private var releasesBinding: Binding<Bool> {
        Binding(
            get: { notifications.releasesEnabled },
            set: { notifications.setReleasesEnabled($0) }
        )
    }

    private var notificationsSection: some View {
        Section {
            Toggle(isOn: notificationsBinding) {
                SettingsRow(
                    icon: "bell.badge.fill",
                    iconColor: Theme.rose,
                    title: L("settings.notif.toggle")
                )
            }
            .tint(Theme.tabSettings)
            .disabled(notifications.isWorking)

            if notifications.isEnabled {
                Toggle(isOn: eveningBinding) {
                    SettingsRow(
                        icon: "moon.stars.fill",
                        iconColor: Theme.tabCinema,
                        title: L("settings.notif.evening")
                    )
                }
                .tint(Theme.tabSettings)

                if notifications.eveningEnabled {
                    DatePicker(
                        selection: eveningTimeBinding,
                        displayedComponents: .hourAndMinute
                    ) {
                        SettingsRow(
                            icon: "clock.fill",
                            iconColor: Theme.tabList,
                            title: L("settings.notif.evening.time")
                        )
                    }
                }

                Toggle(isOn: watchlistNotifBinding) {
                    SettingsRow(
                        icon: "bookmark.fill",
                        iconColor: Theme.primary,
                        title: L("settings.notif.watchlist")
                    )
                }
                .tint(Theme.tabSettings)

                Toggle(isOn: releasesBinding) {
                    SettingsRow(
                        icon: "sparkles",
                        iconColor: Theme.amber,
                        title: L("settings.notif.releases")
                    )
                }
                .tint(Theme.tabSettings)
            }

            if notifications.authorizationStatus == .denied {
                Button {
                    openSystemSettings()
                } label: {
                    SettingsRow(
                        icon: "gear.badge.xmark",
                        iconColor: Theme.inkSoft,
                        title: L("settings.notif.denied"),
                        showsExternalBadge: true
                    )
                }
            }
        } header: {
            Text(L("settings.notif.header"))
        } footer: {
            Text(L("settings.notif.footer2"))
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
                    title: L("settings.list.toggle")
                )
            }
            .tint(Theme.tabSettings)
        } header: {
            Text(L("settings.list.header"))
        } footer: {
            Text(L("settings.list.footer"))
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
        }
        .listRowBackground(Theme.card)
    }

    // MARK: - Introduzione

    private var onboardingSection: some View {
        Section {
            Button {
                hasCompletedOnboarding = false
                showOnboarding = true
            } label: {
                SettingsRow(
                    icon: "arrow.counterclockwise.circle.fill",
                    iconColor: Theme.tabTrending,
                    title: L("settings.intro.review")
                )
            }
            .sensoryFeedback(.impact(weight: .light), trigger: showOnboarding)
        } header: {
            Text(L("settings.intro.header"))
        } footer: {
            Text(L("settings.intro.footer"))
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
        Section(L("settings.privacy.header")) {
            NavigationLink(value: LegalPage.privacyPolicy) {
                SettingsRow(
                    icon: "hand.raised.fill",
                    iconColor: Theme.tabCinema,
                    title: L("settings.privacy.policy")
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
                    title: L("settings.support.report"),
                    showsExternalBadge: true
                )
            }

            NavigationLink {
                FAQView()
            } label: {
                SettingsRow(
                    icon: "questionmark.circle.fill",
                    iconColor: Theme.amber,
                    title: L("settings.support.faq")
                )
            }
        } header: {
            Text(L("settings.support.header"))
        } footer: {
            Text(L("settings.support.footer"))
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
                    title: L("settings.legal.terms")
                )
            }
        } header: {
            Text(L("settings.legal.header"))
        } footer: {
            Text(L("settings.legal.footer"))
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
        .accessibilityLabel(palette.displayName)
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
                    .accessibilityLabel(L("settings.external"))
            }
        }
        .contentShape(.rect)
    }
}

#Preview {
    SettingsView()
        .environment(NotificationService())
        .environment(MovieLibrary())
        .environment(MoodDiary())
}
