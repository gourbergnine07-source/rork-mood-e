//
//  MoodEApp.swift
//  MoodE
//
//  Created by Rork on July 17, 2026.
//

import SwiftUI
import UserNotifications
import AppIntents
import FirebaseCore

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
        // Firebase (Analytics): required for the AdMob ↔ Firebase link (ARPU).
        FirebaseApp.configure()
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        // Make the "what to watch" command discoverable by Siri right away.
        MoodEShortcuts.updateAppShortcutParameters()
        // In-App Purchases (Premium): configure once, before any use.
        PremiumStore.configureSDK()
        PremiumStore.shared.start()
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
                    // Counts this launch as one day of use: feeds the
                    // "used on 3 different days" rating milestone.
                    ReviewPrompter.recordSession()
                    // Keep the interactive widget's mood list fresh even
                    // before the first check-in of the day.
                    diary.publishWidgetSnapshot()
                    CloudSyncService.shared.configure(
                        auth: auth,
                        diary: diary,
                        library: library,
                        planner: planner
                    )
                    ICloudSyncService.shared.configure(
                        diary: diary,
                        library: library,
                        planner: planner
                    )
                    await auth.checkAuth()
                    await CloudSyncService.shared.syncIfSignedIn()
                    await ICloudSyncService.shared.syncIfPremium()
                    // Silently compares this build with the version declared
                    // on the backend (no new build needed to change it).
                    await AppUpdateService.shared.check()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    ReviewPrompter.recordSession()
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
                        await ICloudSyncService.shared.syncIfPremium()
                        await AppUpdateService.shared.check()
                        await AnalyticsService.shared.flush()
                    }
                }
        }
    }
}
