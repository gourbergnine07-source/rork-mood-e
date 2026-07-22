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
    @Environment(AuthManager.self) private var auth
    @Environment(QuizStore.self) private var quiz
    @State private var showPermissionAlert = false
    @State private var showOnboarding = false
    @State private var nicknameRefreshTrigger = false
    @State private var showAccountSheet = false
    @State private var showSignOutConfirm = false
    @State private var showDeleteAccountConfirm = false
    @State private var isDeletingAccount = false
    @State private var showDeleteAccountError = false
    @State private var showPaywall = false
    private var cloudSync: CloudSyncService { CloudSyncService.shared }
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
                premiumSection
                accountSection
                journeySection
                communitySection
                appearanceSection
                personalizationSection
                languageSection
                notificationsSection
                librarySection
                siriSection
                onboardingSection
                if !premium.isPremium {
                    adsSection
                }
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
                case .stats: MyStatsView()
                case .friends: FriendsView()
                }
            }
            .sheet(isPresented: $showAccountSheet) {
                AccountSheetView()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .alert(L("premium.restore"), isPresented: restoreAlertBinding) {
                Button(L("common.ok"), role: .cancel) { premium.restoreMessage = nil }
            } message: {
                Text(premium.restoreMessage ?? "")
            }
            .confirmationDialog(L("account.signOut.confirm"), isPresented: $showSignOutConfirm, titleVisibility: .visible) {
                Button(L("account.signOut"), role: .destructive) {
                    Task {
                        CloudSyncService.shared.cancelPendingUpload()
                        await auth.signOut()
                    }
                }
                Button(L("common.cancel"), role: .cancel) {}
            } message: {
                Text(L("account.signOut.msg"))
            }
            .confirmationDialog(L("account.delete.confirm"), isPresented: $showDeleteAccountConfirm, titleVisibility: .visible) {
                Button(L("account.delete"), role: .destructive) {
                    Task { await deleteAccount() }
                }
                Button(L("common.cancel"), role: .cancel) {}
            } message: {
                Text(L("account.delete.msg"))
            }
            .alert(L("account.error.title"), isPresented: $showDeleteAccountError) {
                Button(L("common.ok"), role: .cancel) {}
            } message: {
                Text(L("account.delete.error"))
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

    // MARK: - Premium

    private var premium: PremiumStore { .shared }
    private var iCloudSync: ICloudSyncService { .shared }

    private var restoreAlertBinding: Binding<Bool> {
        Binding(
            get: { premium.restoreMessage != nil },
            set: { if !$0 { premium.restoreMessage = nil } }
        )
    }

    private var premiumSection: some View {
        Section {
            if premium.isPremium {
                HStack(spacing: 12) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 29, height: 29)
                        .background(Theme.amber, in: .rect(cornerRadius: 7))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(L("premium.active"))
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        Text(L("premium.active.sub"))
                            .font(.caption)
                            .foregroundStyle(Theme.inkSoft)
                    }

                    Spacer()

                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.seenGreen)
                }

                iCloudSyncRow

                Button {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        openURL(url)
                    }
                } label: {
                    SettingsRow(
                        icon: "creditcard.fill",
                        iconColor: Theme.tabSettings,
                        title: L("premium.manage"),
                        showsExternalBadge: true
                    )
                }
            } else {
                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 29, height: 29)
                            .background(Theme.amber, in: .rect(cornerRadius: 7))

                        VStack(alignment: .leading, spacing: 1) {
                            Text(L("premium.row"))
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                            Text(L("premium.row.sub"))
                                .font(.caption)
                                .foregroundStyle(Theme.inkSoft)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }

            Button {
                Task { await premium.restore() }
            } label: {
                SettingsRow(
                    icon: "arrow.clockwise.circle.fill",
                    iconColor: Theme.tabHome,
                    title: L("premium.restore")
                )
            }
            .disabled(premium.isPurchasing)
        } header: {
            Text(L("premium.header"))
        } footer: {
            Text(L("premium.footer"))
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
        }
        .listRowBackground(Theme.card)
    }

    /// Premium-only: iCloud (CloudKit) sync status with a manual refresh.
    private var iCloudSyncRow: some View {
        HStack(spacing: 12) {
            Image(systemName: iCloudSync.status == .error ? "exclamationmark.icloud.fill" : "icloud.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 29, height: 29)
                .background(iCloudSync.status == .error ? Theme.rose : Theme.tabSettings, in: .rect(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 1) {
                Text(L("premium.icloud.status"))
                    .font(.body)
                    .foregroundStyle(Theme.ink)
                Text(iCloudSyncLabel)
                    .font(.caption)
                    .foregroundStyle(iCloudSync.status == .error ? Theme.rose : Theme.inkSoft)
            }

            Spacer()

            if iCloudSync.status == .syncing {
                ProgressView()
            } else {
                Button {
                    Task { await ICloudSyncService.shared.syncIfPremium() }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.tabSettings)
                        .frame(width: 32, height: 32)
                        .background(Theme.tabSettings.opacity(0.12), in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L("account.syncNow"))
            }
        }
    }

    private var iCloudSyncLabel: String {
        switch iCloudSync.status {
        case .unavailable: return L("premium.icloud.unavailable")
        case .error: return L("account.error")
        default: break
        }
        guard let lastSync = iCloudSync.lastSync else { return L("premium.icloud.never") }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = LocalizationManager.shared.locale
        formatter.unitsStyle = .short
        return formatter.localizedString(for: lastSync, relativeTo: Date())
    }

    // MARK: - Account e sincronizzazione

    private var accountSection: some View {
        Section {
            if let user = auth.user {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 29, height: 29)
                        .background(Theme.seenGreen, in: .rect(cornerRadius: 7))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(user.name ?? user.email)
                            .font(.body)
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        if user.name != nil, !user.email.isEmpty {
                            Text(user.email)
                                .font(.caption)
                                .foregroundStyle(Theme.inkSoft)
                                .lineLimit(1)
                        }
                    }
                }

                HStack(spacing: 12) {
                    Image(systemName: cloudSync.status == .error ? "exclamationmark.icloud.fill" : "checkmark.icloud.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 29, height: 29)
                        .background(cloudSync.status == .error ? Theme.rose : Theme.tabSettings, in: .rect(cornerRadius: 7))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(L("account.lastSync"))
                            .font(.body)
                            .foregroundStyle(Theme.ink)
                        Text(lastSyncLabel)
                            .font(.caption)
                            .foregroundStyle(cloudSync.status == .error ? Theme.rose : Theme.inkSoft)
                    }

                    Spacer()

                    if cloudSync.status == .syncing {
                        ProgressView()
                    } else {
                        Button {
                            Task { await CloudSyncService.shared.syncNow() }
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.tabSettings)
                                .frame(width: 32, height: 32)
                                .background(Theme.tabSettings.opacity(0.12), in: .circle)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L("account.syncNow"))
                    }
                }

                Button(role: .destructive) {
                    showSignOutConfirm = true
                } label: {
                    SettingsRow(
                        icon: "rectangle.portrait.and.arrow.right",
                        iconColor: Theme.rose,
                        title: L("account.signOut")
                    )
                }

                Button(role: .destructive) {
                    showDeleteAccountConfirm = true
                } label: {
                    HStack {
                        SettingsRow(
                            icon: "trash.fill",
                            iconColor: Theme.rose,
                            title: L("account.delete")
                        )
                        if isDeletingAccount {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isDeletingAccount)
            } else {
                Button {
                    showAccountSheet = true
                } label: {
                    SettingsRow(
                        icon: "icloud.fill",
                        iconColor: Theme.tabSettings,
                        title: L("account.signIn")
                    )
                }
            }
        } header: {
            Text(L("account.header"))
        } footer: {
            Text(L("account.footer"))
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
        }
        .listRowBackground(Theme.card)
    }

    /// Deletes all cloud data for the account, then signs the user out.
    /// Required by App Store guideline 5.1.1(v).
    private func deleteAccount() async {
        isDeletingAccount = true
        defer { isDeletingAccount = false }
        do {
            try await CloudSyncService.shared.deleteAccountData()
            await auth.signOut()
        } catch {
            print("Settings: account deletion failed: \(error.localizedDescription)")
            showDeleteAccountError = true
        }
    }

    private var lastSyncLabel: String {
        if cloudSync.status == .error { return L("account.error") }
        guard let lastSync = cloudSync.lastSync else { return L("account.never") }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = LocalizationManager.shared.locale
        formatter.unitsStyle = .short
        return formatter.localizedString(for: lastSync, relativeTo: Date())
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

    // MARK: - Personalizzazione e profilo spettatore

    private var personalizationSection: some View {
        Section {
            NavigationLink {
                PersonalizationView()
            } label: {
                SettingsRow(
                    icon: "paintpalette.fill",
                    iconColor: Theme.amber,
                    title: L("settings.perso.row")
                )
            }

            if premium.isPremium {
                NavigationLink {
                    SpectatorQuizView()
                } label: {
                    quizRowLabel
                }
            } else {
                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: 12) {
                        quizRowLabel
                        Spacer()
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.amber)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text(L("settings.perso.header"))
        } footer: {
            Text(L("settings.perso.footer"))
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
        }
        .listRowBackground(Theme.card)
    }

    private var quizRowLabel: some View {
        HStack(spacing: 12) {
            Text(quiz.profile?.emoji ?? "\u{1F3AD}")
                .font(.system(size: 20))
                .frame(width: 29, height: 29)

            VStack(alignment: .leading, spacing: 1) {
                Text(L("quiz.settings.row"))
                    .font(.body)
                    .foregroundStyle(Theme.ink)
                Text(premium.isPremium
                    ? (quiz.profile?.title ?? L("quiz.settings.sub.none"))
                    : L("premium.locked"))
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
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

    // MARK: - Community

    private var communitySection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 29, height: 29)
                    .background(Theme.tabTrending, in: .rect(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 1) {
                    Text(L("settings.community.nickname"))
                        .font(.body)
                        .foregroundStyle(Theme.ink)
                    Text(CommunityService.shared.nickname)
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }

                Spacer()

                Button {
                    CommunityService.shared.regenerateNickname()
                    nicknameRefreshTrigger.toggle()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.tabTrending)
                        .frame(width: 32, height: 32)
                        .background(Theme.tabTrending.opacity(0.12), in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L("settings.community.regenerate"))
                .sensoryFeedback(.impact(weight: .light), trigger: nicknameRefreshTrigger)
            }

            HStack(spacing: 12) {
                Image(systemName: "hand.thumbsup.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 29, height: 29)
                    .background(Theme.seenGreen, in: .rect(cornerRadius: 7))

                Text(L("settings.community.helpful"))
                    .font(.body)
                    .foregroundStyle(Theme.ink)

                Spacer()

                Text("\(CommunityService.shared.profile.helpfulReceived)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.inkSoft)
                    .monospacedDigit()
            }
        } header: {
            Text(L("settings.community.header"))
        } footer: {
            Text(L("settings.community.footer"))
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
        }
        .listRowBackground(Theme.card)
        .task {
            await CommunityService.shared.refreshProfile()
        }
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
                            topGenres: diary.topGenreIds,
                            checkIns: diary.checkIns
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

    private var communityNotifBinding: Binding<Bool> {
        Binding(
            get: { notifications.communityEnabled },
            set: { notifications.setCommunityEnabled($0) }
        )
    }

    private var forecastBinding: Binding<Bool> {
        Binding(
            get: { notifications.forecastEnabled },
            set: { notifications.setForecastEnabled($0, checkIns: diary.checkIns) }
        )
    }

    private var eventsBinding: Binding<Bool> {
        Binding(
            get: { notifications.eventsEnabled },
            set: { notifications.setEventsEnabled($0) }
        )
    }

    private var eventsHeadsUpBinding: Binding<Bool> {
        Binding(
            get: { notifications.eventsHeadsUpEnabled },
            set: { notifications.setEventsHeadsUpEnabled($0) }
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

                Toggle(isOn: communityNotifBinding) {
                    SettingsRow(
                        icon: "bubble.left.and.bubble.right.fill",
                        iconColor: Theme.tabTrending,
                        title: L("settings.notif.community")
                    )
                }
                .tint(Theme.tabSettings)

                Toggle(isOn: forecastBinding) {
                    SettingsRow(
                        icon: "cloud.sun.fill",
                        iconColor: Theme.tabHome,
                        title: L("settings.notif.forecast")
                    )
                }
                .tint(Theme.tabSettings)

                Toggle(isOn: eventsBinding) {
                    SettingsRow(
                        icon: "trophy.fill",
                        iconColor: Theme.amber,
                        title: L("settings.notif.events")
                    )
                }
                .tint(Theme.tabSettings)

                if notifications.eventsEnabled {
                    Toggle(isOn: eventsHeadsUpBinding) {
                        SettingsRow(
                            icon: "calendar.badge.clock",
                            iconColor: Theme.tabList,
                            title: L("settings.notif.events.pre")
                        )
                    }
                    .tint(Theme.tabSettings)
                }
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

    // MARK: - Siri

    private var siriSection: some View {
        Section {
            NavigationLink {
                SiriCommandsView()
            } label: {
                HStack(spacing: 0) {
                    SettingsRow(
                        icon: "waveform",
                        iconColor: Color(red: 0.57, green: 0.42, blue: 0.83),
                        title: L("settings.siri.row")
                    )
                    if !premium.isPremium {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.amber)
                    }
                }
            }
        } header: {
            Text(L("settings.siri.header"))
        } footer: {
            Text(L("settings.siri.footer"))
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
        .environment(AuthManager())
        .environment(QuizStore())
        .environment(PersonalizationStore())
        .environment(MoviePlanner())
}
