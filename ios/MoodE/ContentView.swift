//
//  ContentView.swift
//  MoodE
//

import SwiftUI

/// Root tab bar navigation for Mood-E.
/// Each tab has its own signature color: the tab bar tint follows the selection.
/// Also handles notification tap routes and widget deep links.
struct ContentView: View {
    @State private var selectedTab: Int = 0
    @State private var deepLinkMovie: TMDBMovie?
    @State private var deepLinkTVShow: TMDBTVShow?
    @State private var invitePrefill: InvitePrefill?
    @State private var showSyncConflict = false
    @State private var showSyncSuccessToast = false
    @State private var syncToastTask: Task<Void, Never>?
    @State private var showLinkErrorToast = false
    @State private var linkErrorTask: Task<Void, Never>?
    @Environment(MovieLibrary.self) private var library
    @Environment(MoodDiary.self) private var diary
    @Environment(MoviePlanner.self) private var planner
    @Environment(PersonalizationStore.self) private var personalization
    @Environment(QuizStore.self) private var quiz

    private var iCloudSync: ICloudSyncService { .shared }

    private var selectedTint: Color {
        switch selectedTab {
        case 0: return Theme.tabHome
        case 1: return Theme.tabTrending
        case 2: return Theme.tabCinema
        case 3: return Theme.tabList
        default: return Theme.tabSettings
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label(L("tab.home"), systemImage: "face.smiling.inverse")
                }
                .tag(0)

            TrendingView()
                .tabItem {
                    Label(L("tab.trending"), systemImage: "flame.fill")
                }
                .tag(1)

            CinemaView()
                .tabItem {
                    Label(L("tab.cinema"), systemImage: "popcorn.fill")
                }
                .tag(2)

            MyListView()
                .tabItem {
                    Label(L("tab.list"), systemImage: "bookmark.fill")
                }
                .badge(library.toWatchCount)
                .tag(3)

            SettingsView()
                .tabItem {
                    Label(L("tab.settings"), systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        .tint(selectedTint)
        .sensoryFeedback(.selection, trigger: selectedTab)
        .animation(.easeInOut(duration: 0.25), value: selectedTab)
        .overlay(alignment: .top) {
            if let reward = personalization.pendingRewards.first {
                UnlockToastView(reward: reward) {
                    personalization.dismissReward(reward)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .id(reward.id)
            } else if showSyncSuccessToast {
                SyncSuccessToastView()
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if showLinkErrorToast {
                DeepLinkErrorToastView()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(
            .spring(response: 0.45, dampingFraction: 0.8),
            value: personalization.pendingRewards
        )
        .animation(
            .spring(response: 0.4, dampingFraction: 0.85),
            value: showSyncSuccessToast
        )
        .animation(
            .spring(response: 0.4, dampingFraction: 0.85),
            value: showLinkErrorToast
        )
        .sensoryFeedback(.impact(weight: .light), trigger: showSyncSuccessToast) { _, newValue in
            newValue
        }
        .onChange(of: iCloudSync.successSignal) { _, _ in
            showSyncSuccessToast = true
            syncToastTask?.cancel()
            syncToastTask = Task {
                try? await Task.sleep(for: .seconds(2.4))
                guard !Task.isCancelled else { return }
                showSyncSuccessToast = false
            }
        }
        .task {
            evaluateUnlocks()
            // Biweekly renewal of the recommendation pool: compared on
            // every app open, advances the discover page rotation when due.
            PoolRotation.shared.renewIfDue()
            // Refresh "new episode" reminders for the followed TV series.
            Task { await TVEpisodeNotifier.sync() }
            // A conflict may have been detected before this view appeared.
            showSyncConflict = iCloudSync.conflict != nil
            // Siri intent fired on a cold start: launch the ready proposal.
            if let mood = IntentRelay.consumePendingMood() {
                launchQuickPick(mood: mood)
            }
            // Navigation is on screen: flush any notification tap queued
            // during the cold start (small delay lets the first layout
            // pass settle before presenting a sheet).
            try? await Task.sleep(for: .milliseconds(600))
            NotificationRouteRelay.markReady()
        }
        .onChange(of: iCloudSync.conflict) { _, newValue in
            showSyncConflict = newValue != nil
        }
        .alert(L("icloud.conflict.title"), isPresented: $showSyncConflict) {
            Button(L("icloud.conflict.merge")) {
                Task { await ICloudSyncService.shared.resolveConflict(applyMerge: true) }
            }
            Button(L("icloud.conflict.keepLocal"), role: .destructive) {
                Task { await ICloudSyncService.shared.resolveConflict(applyMerge: false) }
            }
        } message: {
            Text(LF("icloud.conflict.msg", String(iCloudSync.conflict?.itemCount ?? 0)))
        }
        .onChange(of: diary.checkIns.count) { _, _ in evaluateUnlocks() }
        .onChange(of: library.lifetimeWatchedCount) { _, _ in evaluateUnlocks() }
        .onReceive(NotificationCenter.default.publisher(for: NotificationRoute.notificationName)) { note in
            guard let payload = note.object as? NotificationTapPayload else { return }
            handleNotificationRoute(payload)
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .sheet(item: $invitePrefill) { invite in
            NavigationStack {
                FriendsView(prefillCode: invite.code)
            }
            .tint(Theme.primary)
        }
        .sheet(item: $deepLinkMovie) { movie in
            NavigationStack {
                MovieDetailView(movie: movie)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                deepLinkMovie = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Theme.inkSoft)
                            }
                            .accessibilityLabel(L("common.close"))
                        }
                    }
            }
            .tint(Theme.primary)
        }
        .sheet(item: $deepLinkTVShow) { show in
            NavigationStack {
                TVShowDetailView(show: show)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                deepLinkTVShow = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Theme.inkSoft)
                            }
                            .accessibilityLabel(L("common.close"))
                        }
                    }
            }
            .tint(Theme.primary)
        }
    }

    /// Routes a notification tap to the right tab or screen. Unknown routes
    /// fall back to the Home tab instead of doing anything risky.
    private func handleNotificationRoute(_ payload: NotificationTapPayload) {
        switch payload.route {
        case NotificationRoute.moodFlow: selectedTab = 0
        case NotificationRoute.community: selectedTab = 1
        case NotificationRoute.watchlist: selectedTab = 3
        case NotificationRoute.forecast: handleForecastTap(payload)
        case NotificationRoute.movie: handleMovieNotificationTap(payload)
        case NotificationRoute.tvShow: handleTVShowNotificationTap(payload)
        default: selectedTab = 0
        }
    }

    /// Discreet toast shown when a notification link can't be resolved:
    /// the app stays usable on the Home instead of crashing or going blank.
    private func showLinkError() {
        showLinkErrorToast = true
        linkErrorTask?.cancel()
        linkErrorTask = Task {
            try? await Task.sleep(for: .seconds(2.6))
            guard !Task.isCancelled else { return }
            showLinkErrorToast = false
        }
    }

    /// Re-checks streak/watched milestones for icons and themes.
    private func evaluateUnlocks() {
        personalization.evaluate(
            diary: diary,
            library: library,
            planner: planner,
            quizCompleted: quiz.profile != nil
        )
    }

    /// Forecast notification tap (also reused by the Siri intent): jump to
    /// Home and open the results screen with the pre-computed mood + goal.
    private func handleForecastTap(_ payload: NotificationTapPayload) {
        // Clear any Siri pending mood so it doesn't re-fire at next launch.
        _ = IntentRelay.consumePendingMood()
        guard let moodRaw = payload.mood,
              let mood = Mood(rawValue: moodRaw) else {
            selectedTab = 0
            return
        }
        let goal = payload.goal.flatMap(ViewingGoal.init)
        launchQuickPick(mood: mood, goal: goal)
    }

    /// Jumps to Home and opens the results screen for a quick-pick selection
    /// (used by forecast notifications, the Siri intent and the widget).
    private func launchQuickPick(mood: Mood, goal: ViewingGoal? = nil) {
        selectedTab = 0
        let selection = MoodSelection(
            mood: mood,
            goal: goal ?? mood.quickPickGoal,
            era: .noPreference,
            isQuickPick: true
        )
        // Small delay so the tab switch settles before pushing the results.
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            NotificationCenter.default.post(name: ForecastLaunch.name, object: selection)
        }
    }

    /// Movie notification tap (watchlist nudge, movie night, new release):
    /// opens the movie's detail page directly. Missing or malformed movie
    /// ids degrade to the Home with a gentle toast — never a crash.
    private func handleMovieNotificationTap(_ payload: NotificationTapPayload) {
        guard let id = payload.movieId, id > 0 else {
            AnalyticsService.shared.log("notification_open_failed", meta: [
                "reason": "invalid_movie_id",
                "route": payload.route
            ])
            selectedTab = 0
            showLinkError()
            return
        }
        // Avoid presenting on top of another active sheet.
        invitePrefill = nil
        let posterPath = payload.posterPath
        deepLinkMovie = TMDBMovie(
            id: id,
            title: payload.movieTitle ?? "",
            overview: "",
            posterPath: (posterPath?.isEmpty == true) ? nil : posterPath,
            backdropPath: nil,
            releaseDate: nil,
            voteAverage: 0,
            voteCount: 0,
            genreIds: nil
        )
    }

    /// TV episode notification tap: opens the show's detail page directly.
    /// Malformed ids degrade to the Home with a gentle toast — never a crash.
    private func handleTVShowNotificationTap(_ payload: NotificationTapPayload) {
        guard let id = payload.movieId, id > 0 else {
            AnalyticsService.shared.log("notification_open_failed", meta: [
                "reason": "invalid_tv_id",
                "route": payload.route
            ])
            selectedTab = 0
            showLinkError()
            return
        }
        invitePrefill = nil
        deepLinkMovie = nil
        let posterPath = payload.posterPath
        deepLinkTVShow = TMDBTVShow(
            id: id,
            name: payload.movieTitle ?? "",
            overview: "",
            posterPath: (posterPath?.isEmpty == true) ? nil : posterPath,
            backdropPath: nil,
            firstAirDate: nil,
            voteAverage: 0,
            voteCount: 0,
            genreIds: nil
        )
    }

    /// Widget and invite deep links:
    /// - moode://movie/<id> opens the movie detail page
    /// - moode://flow/<mood> opens the results screen for that emotion
    /// - moode://invite/<code> opens Friends with the code pre-filled
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "moode" else { return }

        switch url.host {
        case "movie":
            guard let id = Int(url.lastPathComponent) else { return }
            openMovieDeepLink(id: id)
        case "flow":
            guard let mood = Mood(rawValue: url.lastPathComponent) else { return }
            AnalyticsService.shared.log("widget_mood_tap", meta: ["mood": mood.rawValue])
            launchQuickPick(mood: mood)
        case "invite":
            let code = url.lastPathComponent
                .uppercased()
                .filter { $0.isLetter || $0.isNumber }
            guard !code.isEmpty else { return }
            AnalyticsService.shared.log("invite_link_opened")
            invitePrefill = InvitePrefill(code: String(code.prefix(12)))
        default:
            break
        }
    }

    private func openMovieDeepLink(id: Int) {
        var title = ""
        var posterPath: String?
        if let shared = UserDefaults(suiteName: MoodDiary.appGroupID),
           let data = shared.data(forKey: MoodDiary.widgetSnapshotKey),
           let snapshot = try? JSONDecoder().decode(DiaryWidgetSnapshot.self, from: data),
           snapshot.movieId == id {
            title = snapshot.movieTitle ?? ""
            posterPath = snapshot.posterPath
        }

        deepLinkMovie = TMDBMovie(
            id: id,
            title: title,
            overview: "",
            posterPath: posterPath,
            backdropPath: nil,
            releaseDate: nil,
            voteAverage: 0,
            voteCount: 0,
            genreIds: nil
        )
    }
}

/// Identifiable wrapper for the friend code arriving via an invite link.
private struct InvitePrefill: Identifiable {
    let code: String
    var id: String { code }
}

/// Small capsule toast shown when a notification deep link can't be opened.
private struct DeepLinkErrorToastView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.amber)
            Text(L("deeplink.error"))
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.card, in: .capsule)
        .overlay(Capsule().strokeBorder(Theme.inkSoft.opacity(0.15), lineWidth: 1))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        .padding(.top, 8)
        .padding(.horizontal, 24)
    }
}

#Preview {
    ContentView()
        .environment(MovieLibrary())
        .environment(MoodDiary())
        .environment(NotificationService())
        .environment(MoviePlanner())
        .environment(PersonalizationStore())
        .environment(QuizStore())
}
