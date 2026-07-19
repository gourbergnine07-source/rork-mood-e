//
//  ScheduleMovieView.swift
//  MoodE
//

import SwiftUI

/// Sheet to plan a movie on a diary day: pick from the watchlist or
/// search TMDB. Selection saves instantly (no separate confirm button);
/// searched movies are also added to the general watchlist.
struct ScheduleMovieView: View {
    let day: Date

    @Environment(MoviePlanner.self) private var planner
    @Environment(MovieLibrary.self) private var library
    @Environment(NotificationService.self) private var notifications
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode = .watchlist
    @State private var query: String = ""
    @State private var results: [TMDBMovie] = []
    @State private var isSearching: Bool = false
    @State private var hasSearched: Bool = false
    @State private var didPick: Bool = false
    @FocusState private var searchFocused: Bool

    private enum Mode: Hashable {
        case watchlist, search
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 12) {
                    Picker("", selection: $mode) {
                        Text(L("planner.fromList")).tag(Mode.watchlist)
                        Text(L("planner.search")).tag(Mode.search)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)

                    switch mode {
                    case .watchlist: watchlistSection
                    case .search: searchSection
                    }
                }
                .padding(.top, 8)
            }
            .navigationTitle(dayTitle)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("common.cancel")) { dismiss() }
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.success, trigger: didPick)
    }

    // MARK: - Watchlist

    private var watchlistSection: some View {
        Group {
            if library.toWatch.isEmpty {
                VStack(spacing: 10) {
                    Text("🎬")
                        .font(.system(size: 40))
                    Text(L("planner.emptyList"))
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.center)
                    Button(L("planner.search")) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            mode = .search
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.primary)
                }
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(library.toWatch) { entry in
                            PlannerMovieRow(
                                title: entry.title,
                                posterURL: entry.posterURL,
                                subtitle: nil
                            ) {
                                pick(entry: entry)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    // MARK: - Search

    private var searchSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                TextField(L("planner.searchPlaceholder"), text: $query)
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                    .focused($searchFocused)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                if !query.isEmpty {
                    Button {
                        query = ""
                        results = []
                        hasSearched = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.inkSoft.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(Theme.card, in: .rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.primary.opacity(0.18), lineWidth: 1)
            )
            .padding(.horizontal, 20)

            if results.isEmpty && !isSearching && !hasSearched {
                Text(L("planner.searchHint"))
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 12)
            }

            if isSearching {
                ProgressView()
                    .tint(Theme.primary)
                    .padding(.top, 16)
            }

            if !isSearching && hasSearched && results.isEmpty && trimmedQuery.count >= 2 {
                Text(LF("planner.noResults", trimmedQuery))
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.top, 16)
            }

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(results) { movie in
                        PlannerMovieRow(
                            title: movie.title,
                            posterURL: movie.posterURL,
                            subtitle: movie.releaseYear
                        ) {
                            pick(movie: movie)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.immediately)
        }
        .task(id: query) {
            let trimmed = trimmedQuery
            guard trimmed.count >= 2 else {
                results = []
                hasSearched = false
                return
            }
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            isSearching = true
            defer { isSearching = false }
            do {
                let found = try await TMDBService.searchMovies(query: trimmed)
                guard !Task.isCancelled else { return }
                results = found
                hasSearched = true
            } catch {
                guard !Task.isCancelled else { return }
                results = []
                hasSearched = true
            }
        }
        .onAppear { searchFocused = true }
    }

    // MARK: - Actions

    private func pick(entry: LibraryEntry) {
        planner.schedule(
            movieId: entry.id,
            title: entry.title,
            posterPath: entry.posterPath,
            genreIds: nil,
            on: day
        )
        finishPick()
    }

    private func pick(movie: TMDBMovie) {
        if library.entry(for: movie.id) == nil {
            library.toggleWatchlist(movie)
        }
        planner.schedule(
            movieId: movie.id,
            title: movie.title,
            posterPath: movie.posterPath,
            genreIds: movie.genreIds,
            on: day
        )
        finishPick()
    }

    private func finishPick() {
        notifications.syncMovieNightReminders(planner.scheduled)
        didPick.toggle()
        dismiss()
    }

    // MARK: - Helpers

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var dayTitle: String {
        let formatter = DateFormatter()
        formatter.locale = LocalizationManager.shared.locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: day)
    }
}

/// Tappable movie row (poster + title) used by both picker sections.
private struct PlannerMovieRow: View {
    let title: String
    let posterURL: URL?
    let subtitle: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                poster
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                Spacer()
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.primary)
            }
            .padding(10)
            .background(Theme.card, in: .rect(cornerRadius: 14))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var poster: some View {
        Group {
            if let posterURL {
                AsyncImage(url: posterURL) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Theme.surface
                }
            } else {
                Theme.surface.overlay {
                    Text("🎬").font(.system(size: 16))
                }
            }
        }
        .frame(width: 42, height: 63)
        .clipShape(.rect(cornerRadius: 8))
    }
}
