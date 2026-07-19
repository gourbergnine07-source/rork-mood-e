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
                .preferredColorScheme(theme.appearance.colorScheme)
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    Task {
                        await notifications.refreshAuthorizationStatus()
                        await NotificationHistory.shared.syncDelivered()
                        await notifications.refreshSchedules(
                            toWatch: library.toWatch,
                            topGenres: diary.topGenreIds
                        )
                    }
                }
        }
    }
}
