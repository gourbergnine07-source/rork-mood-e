//
//  MoodEApp.swift
//  MoodE
//
//  Created by Rork on July 17, 2026.
//

import SwiftUI
import UserNotifications

@main
struct MoodEApp: App {
    @State private var library = MovieLibrary()
    @State private var notifications = NotificationService()
    @State private var diary = MoodDiary()
    @State private var planner = MoviePlanner()
    @State private var auth = AuthManager()
    @State private var statsStore = MovieStatsStore()
    @State private var personalization = PersonalizationStore()
    @State private var quiz = QuizStore()
    @State private var theme = ThemeManager.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(library)
                .environment(notifications)
                .environment(diary)
                .environment(planner)
                .environment(auth)
                .environment(statsStore)
                .environment(personalization)
                .environment(quiz)
                .preferredColorScheme(theme.appearance.colorScheme)
                .task {
                    CloudSyncService.shared.configure(
                        auth: auth,
                        diary: diary,
                        library: library,
                        planner: planner
                    )
                    await auth.checkAuth()
                    await CloudSyncService.shared.syncIfSignedIn()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    Task {
                        await notifications.refreshAuthorizationStatus()
                        await NotificationHistory.shared.syncDelivered()
                        await notifications.refreshSchedules(
                            toWatch: library.toWatch,
                            topGenres: diary.topGenreIds,
                            scheduled: planner.scheduled,
                            checkIns: diary.checkIns
                        )
                        await CommunityService.shared.checkActivity(
                            notifications: notifications,
                            topMood: diary.topMood
                        )
                        await CloudSyncService.shared.syncIfSignedIn()
                        await AnalyticsService.shared.flush()
                    }
                }
        }
    }
}
