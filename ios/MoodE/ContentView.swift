//
//  ContentView.swift
//  MoodE
//

import SwiftUI

/// Root tab bar navigation for Mood-E.
/// Each tab has its own signature color: the tab bar tint follows the selection.
struct ContentView: View {
    @State private var selectedTab: Int = 0
    @Environment(MovieLibrary.self) private var library

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
    }
}

#Preview {
    ContentView()
        .environment(MovieLibrary())
}
