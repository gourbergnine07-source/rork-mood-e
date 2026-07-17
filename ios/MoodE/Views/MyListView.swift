//
//  MyListView.swift
//  MoodE
//

import SwiftUI

/// La mia lista tab: will host the watchlist and "already seen" movies.
struct MyListView: View {
    @State private var selectedSection: ListSection = .watchlist

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    Picker("Sezione", selection: $selectedSection) {
                        ForEach(ListSection.allCases) { section in
                            Text(section.title).tag(section)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                    Spacer()

                    PlaceholderCard(
                        icon: selectedSection.icon,
                        title: selectedSection.placeholderTitle,
                        message: selectedSection.placeholderMessage
                    )

                    Spacer()
                }
            }
            .navigationTitle("La mia lista")
            .toolbarTitleDisplayMode(.large)
        }
        .tint(Theme.primary)
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
}
