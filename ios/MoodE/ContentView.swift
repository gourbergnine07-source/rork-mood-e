//
//  ContentView.swift
//  MoodE
//

import SwiftUI

/// Root tab bar navigation for Mood-E.
struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "face.smiling")
                }

            TrendingView()
                .tabItem {
                    Label("Tendenze", systemImage: "flame")
                }

            CinemaView()
                .tabItem {
                    Label("Al Cinema", systemImage: "popcorn")
                }

            MyListView()
                .tabItem {
                    Label("La mia lista", systemImage: "bookmark")
                }
        }
        .tint(Theme.primary)
    }
}

#Preview {
    ContentView()
}
