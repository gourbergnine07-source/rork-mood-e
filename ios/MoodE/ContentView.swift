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
        .onReceive(NotificationCenter.default.publisher(for: NotificationRoute.notificationName)) { note in
            guard let route = note.object as? String else { return }
            switch route {
            case NotificationRoute.moodFlow: selectedTab = 0
            case NotificationRoute.community: selectedTab = 1
            case NotificationRoute.watchlist: selectedTab = 3
            default: break
            }
        }
        .onOpenURL { url in
            handleDeepLink(url)
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

    /// Widget deep link: moode://movie/<id> opens the movie detail page.
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "moode", url.host == "movie",
              let id = Int(url.lastPathComponent) else { return }

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

#Preview {
    ContentView()
        .environment(MovieLibrary())
        .environment(MoodDiary())
        .environment(NotificationService())
}
