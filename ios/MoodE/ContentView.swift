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
    @State private var invitePrefill: InvitePrefill?
    @State private var showSyncConflict = false
    @State private var showSyncSuccessToast = false
    @State private var syncToastTask: Task<Void, Never>?
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
            // A conflict may have been detected before this view appeared.
            showSyncConflict = iCloudSync.conflict != nil
            // Siri intent fired on a cold start: launch the ready proposal.
            if let mood = IntentRelay.consumePendingMood() {
                launchQuickPick(mood: mood)
            }
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
            guard let route = note.object as? String else { return }
            switch route {
            case NotificationRoute.moodFlow: selectedTab = 0
            case NotificationRoute.community: selectedTab = 1
            case NotificationRoute.watchlist: selectedTab = 3
            case NotificationRoute.forecast: handleForecastTap(note.userInfo)
            default: break
            }
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
    private func handleForecastTap(_ userInfo: [AnyHashable: Any]?) {
        // Clear any Siri pending mood so it doesn't re-fire at next launch.
        _ = IntentRelay.consumePendingMood()
        guard let moodRaw = userInfo?["mood"] as? String,
              let mood = Mood(rawValue: moodRaw) else {
            selectedTab = 0
            return
        }
        let goal = (userInfo?["goal"] as? String).flatMap(ViewingGoal.init)
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

#Preview {
    ContentView()
        .environment(MovieLibrary())
        .environment(MoodDiary())
        .environment(NotificationService())
        .environment(MoviePlanner())
        .environment(PersonalizationStore())
        .environment(QuizStore())
}
