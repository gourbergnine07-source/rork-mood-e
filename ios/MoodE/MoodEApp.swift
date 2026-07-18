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
    @State private var theme = ThemeManager.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(library)
                .environment(notifications)
                .preferredColorScheme(theme.appearance.colorScheme)
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    Task {
                        await notifications.refreshAuthorizationStatus()
                        await notifications.sync()
                    }
                }
        }
    }
}
