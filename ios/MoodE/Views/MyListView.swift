//
//  MyListView.swift
//  MoodE
//

import SwiftUI

/// La mia lista tab: local watchlist and "already seen" movies.
struct MyListView: View {
    @State private var selectedSection: ListSection = .watchlist
    @Environment(MovieLibrary.self) private var library

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 16) {
                    Picker("Sezione", selection: $selectedSection) {
                        ForEach(ListSection.allCases) { section in
                            Text(section.title).tag(section)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                    if movies.isEmpty {
                        Spacer()
                        PlaceholderCard(
                            icon: selectedSection.icon,
                            title: selectedSection.placeholderTitle,
                            message: selectedSection.placeholderMessage
                        )
                        Spacer()
                    } else {
                        movieList
                    }
                }
            }
            .navigationTitle("La mia lista")
            .toolbarTitleDisplayMode(.large)
            .navigationDestination(for: TMDBMovie.self) { movie in
                MovieDetailView(movie: movie)
            }
        }
        .tint(Theme.tabList)
        .sensoryFeedback(.selection, trigger: selectedSection)
    }

    private var movies: [TMDBMovie] {
        switch selectedSection {
        case .watchlist: return library.watchlist
        case .seen: return library.seen
        }
    }

    private var movieList: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(movies) { movie in
                    NavigationLink(value: movie) {
                        MovieCard(movie: movie)
                    }
                    .buttonStyle(PressableCardStyle())
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: movies)
    }
}

/// Sections of the personal list.
enum ListSection: String, CaseIterable, Identifiable {
    case watchlist
    case seen

    var id: String { rawValue }

    var title: String {
        switch self {
        case .watchlist: return "Da vedere"
        case .seen: return "Già visti"
        }
    }

    var icon: String {
        switch self {
        case .watchlist: return "bookmark"
        case .seen: return "checkmark.circle"
        }
    }

    var placeholderTitle: String {
        switch self {
        case .watchlist: return "La tua watchlist"
        case .seen: return "Film già visti"
        }
    }

    var placeholderMessage: String {
        switch self {
        case .watchlist:
            return "Salva qui i film che vuoi guardare: resteranno sul tuo dispositivo, senza bisogno di account."
        case .seen:
            return "Tieni traccia dei film che hai già visto, così Mood-E non te li consiglierà di nuovo."
        }
    }
}

#Preview {
    MyListView()
        .environment(MovieLibrary())
}
