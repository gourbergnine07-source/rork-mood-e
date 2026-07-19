//
//  MyListView.swift
//  MoodE
//

import SwiftUI
import StoreKit

/// La mia lista tab: local "to watch" and "watched" lists with live updates.
struct MyListView: View {
    @State private var selectedSection: ListSection = .watchlist
    @State private var trailerPlayback = TrailerPlayback()
    @Environment(MovieLibrary.self) private var library
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 16) {
                    Picker(L("list.section"), selection: $selectedSection) {
                        ForEach(ListSection.allCases) { section in
                            Text(sectionLabel(section)).tag(section)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                    if entries.isEmpty {
                        Spacer()
                        EmptyLibraryCard(section: selectedSection)
                        Spacer()
                    } else {
                        entryList
                    }
                }
            }
            .navigationTitle(L("tab.list"))
            .toolbarTitleDisplayMode(.large)
            .navigationDestination(for: TMDBMovie.self) { movie in
                MovieDetailView(movie: movie)
            }
            .trailerPlayer(trailerPlayback)
        }
        .tint(Theme.tabList)
        .sensoryFeedback(.selection, trigger: selectedSection)
        .onAppear { library.pruneExpiredWatched() }
    }

    private var entries: [LibraryEntry] {
        switch selectedSection {
        case .watchlist: return library.toWatch
        case .seen: return library.watched
        }
    }

    private func sectionLabel(_ section: ListSection) -> String {
        switch section {
        case .watchlist:
            let count = library.toWatchCount
            return count > 0 ? "\(L("list.toWatch")) (\(count))" : L("list.toWatch")
        case .seen:
            let count = library.watched.count
            return count > 0 ? "\(L("list.seen")) (\(count))" : L("list.seen")
        }
    }

    /// Asks for an App Store rating right after marking a movie as watched,
    /// respecting ReviewPrompter's cooldown rules.
    private func maybeRequestReview() {
        guard ReviewPrompter.shouldPrompt(lifetimeWatched: library.lifetimeWatchedCount) else { return }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            requestReview()
        }
    }

    private var entryList: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(entries) { entry in
                    LibraryEntryRow(
                        entry: entry,
                        onMarkWatched: entry.status == .toWatch ? {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                library.markWatched(entry.id)
                            }
                            maybeRequestReview()
                        } : nil,
                        onRemove: entry.status == .watched ? {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                library.removeEntry(entry.id)
                            }
                        } : nil,
                        isLoadingTrailer: trailerPlayback.loadingMovieId == entry.id,
                        onPlayTrailer: { trailerPlayback.play(entry.asMovie) }
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .scale(scale: 0.92))
                    ))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: library.entries)
    }
}

/// Row for a saved movie: poster + info open the detail, with an optional
/// quick "mark as watched" action directly from the list.
struct LibraryEntryRow: View {
    let entry: LibraryEntry
    let onMarkWatched: (() -> Void)?
    var onRemove: (() -> Void)? = nil
    var isLoadingTrailer: Bool = false
    var onPlayTrailer: (() -> Void)? = nil

    @State private var justMarked: Bool = false
    @State private var justRemoved: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            NavigationLink(value: entry.asMovie) {
                HStack(alignment: .center, spacing: 14) {
                    poster

                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.title)
                            .font(.headline)
                            .foregroundStyle(Theme.ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        dateLabel

                        if let onPlayTrailer {
                            WatchTrailerButton(
                                tint: Theme.tabList,
                                isCompact: true,
                                isLoading: isLoadingTrailer,
                                action: onPlayTrailer
                            )
                            .padding(.top, 2)
                        }
                    }

                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            MovieShareButton(
                movieTitle: entry.title,
                message: shareMessage,
                tint: Theme.tabList
            )

            if let onMarkWatched {
                quickWatchedButton(onMarkWatched)
            } else if let onRemove {
                removeButton(onRemove)
            } else {
                watchedBadge
            }
        }
        .padding(12)
        .background(Theme.card, in: .rect(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Theme.tabList.opacity(0.12), lineWidth: 1)
        )
    }

    /// Share text for a saved movie: title plus its TMDB page.
    private var shareMessage: String {
        "\u{1F3AC} \(entry.title)\nhttps://www.themoviedb.org/movie/\(entry.id)"
    }

    private var dateLabel: some View {
        let dateStyle = Date.FormatStyle.dateTime.day().month(.abbreviated)
            .locale(LocalizationManager.shared.locale)
        return Group {
            if entry.status == .watched, let watchedDate = entry.watchedDate {
                Label(
                    LF("list.watchedOn", watchedDate.formatted(dateStyle)),
                    systemImage: "checkmark.circle.fill"
                )
                .foregroundStyle(Theme.seenGreen)
            } else {
                Label(
                    LF("list.addedOn", entry.addedDate.formatted(dateStyle)),
                    systemImage: "bookmark.fill"
                )
                .foregroundStyle(Theme.tabList)
            }
        }
        .font(.caption.weight(.semibold))
    }

    /// Quick action: mark as watched without opening the detail screen.
    private func quickWatchedButton(_ action: @escaping () -> Void) -> some View {
        Button {
            justMarked = true
            action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 24, weight: .semibold))
                Text(L("list.markSeen"))
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(Theme.seenGreen)
            .frame(width: 56, height: 64)
            .background(Theme.seenGreen.opacity(0.12), in: .rect(cornerRadius: 16))
        }
        .buttonStyle(PressableCardStyle())
        .sensoryFeedback(.success, trigger: justMarked)
        .accessibilityLabel(LF("list.a11y.markSeen", entry.title))
    }

    /// Quick action: remove a watched movie from the library.
    private func removeButton(_ action: @escaping () -> Void) -> some View {
        Button {
            justRemoved = true
            action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "trash")
                    .font(.system(size: 22, weight: .semibold))
                Text(L("list.remove"))
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(Theme.rose)
            .frame(width: 56, height: 64)
            .background(Theme.rose.opacity(0.12), in: .rect(cornerRadius: 16))
        }
        .buttonStyle(PressableCardStyle())
        .sensoryFeedback(.impact(weight: .medium), trigger: justRemoved)
        .accessibilityLabel(LF("list.a11y.remove", entry.title))
    }

    private var watchedBadge: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 26))
            .foregroundStyle(Theme.seenGreen)
            .padding(.trailing, 4)
            .accessibilityHidden(true)
    }

    private var poster: some View {
        Color(Theme.surface)
            .frame(width: 68, height: 98)
            .overlay {
                if let url = entry.posterURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .allowsHitTesting(false)
                        case .failure:
                            posterFallback
                        default:
                            ProgressView()
                                .tint(Theme.tabList)
                        }
                    }
                } else {
                    posterFallback
                }
            }
            .clipShape(.rect(cornerRadius: 12))
    }

    private var posterFallback: some View {
        Image(systemName: "film")
            .font(.system(size: 22))
            .foregroundStyle(Theme.tabList.opacity(0.4))
    }
}

/// Friendly empty state with a floating illustration, per section.
struct EmptyLibraryCard: View {
    let section: ListSection

    @State private var isFloating: Bool = false

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Theme.tabList.opacity(0.12))
                    .frame(width: 110, height: 110)
                Circle()
                    .fill(Theme.tabList.opacity(0.10))
                    .frame(width: 82, height: 82)

                Image(systemName: section.emptyIcon)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(Theme.tabList)
                    .offset(y: isFloating ? -6 : 4)
                    .animation(
                        .easeInOut(duration: 1.8).repeatForever(autoreverses: true),
                        value: isFloating
                    )

                Text(section.emptyEmoji)
                    .font(.system(size: 26))
                    .offset(x: 42, y: -38)
                    .rotationEffect(.degrees(isFloating ? 8 : -6))
                    .animation(
                        .easeInOut(duration: 2.2).repeatForever(autoreverses: true),
                        value: isFloating
                    )
            }

            Text(section.emptyTitle)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)

            Text(section.emptyMessage)
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(Theme.card, in: .rect(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Theme.tabList.opacity(0.12), lineWidth: 1)
        )
        .padding(.horizontal, 24)
        .onAppear { isFloating = true }
    }
}

/// Sections of the personal list.
enum ListSection: String, CaseIterable, Identifiable {
    case watchlist
    case seen

    var id: String { rawValue }

    var emptyIcon: String {
        switch self {
        case .watchlist: return "bookmark"
        case .seen: return "checkmark.circle"
        }
    }

    var emptyEmoji: String {
        switch self {
        case .watchlist: return "🍿"
        case .seen: return "🎬"
        }
    }

    var emptyTitle: String {
        switch self {
        case .watchlist: return L("list.empty.watch.title")
        case .seen: return L("list.empty.seen.title")
        }
    }

    var emptyMessage: String {
        switch self {
        case .watchlist: return L("list.empty.watch.msg")
        case .seen: return L("list.empty.seen.msg")
        }
    }
}

#Preview {
    MyListView()
        .environment(MovieLibrary())
}
