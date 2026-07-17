//
//  MyListView.swift
//  MoodE
//

import SwiftUI

/// La mia lista tab: local "to watch" and "watched" lists with live updates.
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
            .navigationTitle("La mia lista")
            .toolbarTitleDisplayMode(.large)
            .navigationDestination(for: TMDBMovie.self) { movie in
                MovieDetailView(movie: movie)
            }
        }
        .tint(Theme.tabList)
        .sensoryFeedback(.selection, trigger: selectedSection)
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
            return count > 0 ? "Da vedere (\(count))" : "Da vedere"
        case .seen:
            let count = library.watched.count
            return count > 0 ? "Già visti (\(count))" : "Già visti"
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
                        } : nil
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

    @State private var justMarked: Bool = false

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
            } else {
                watchedBadge
            }
        }
        .padding(12)
        .background(.white.opacity(0.65), in: .rect(cornerRadius: 22))
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
        Group {
            if entry.status == .watched, let watchedDate = entry.watchedDate {
                Label(
                    "Visto il \(watchedDate.formatted(.dateTime.day().month(.abbreviated)))",
                    systemImage: "checkmark.circle.fill"
                )
                .foregroundStyle(Theme.seenGreen)
            } else {
                Label(
                    "Aggiunto il \(entry.addedDate.formatted(.dateTime.day().month(.abbreviated)))",
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
                Text("Visto")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(Theme.seenGreen)
            .frame(width: 56, height: 64)
            .background(Theme.seenGreen.opacity(0.12), in: .rect(cornerRadius: 16))
        }
        .buttonStyle(PressableCardStyle())
        .sensoryFeedback(.success, trigger: justMarked)
        .accessibilityLabel("Segna \(entry.title) come visto")
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
        .background(.white.opacity(0.65), in: .rect(cornerRadius: 28))
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
        case .watchlist: return "Nessun film da vedere"
        case .seen: return "Nessun film già visto"
        }
    }

    var emptyMessage: String {
        switch self {
        case .watchlist:
            return "Non hai ancora film da vedere: esplora le proposte nella Home e salva quelli che ti incuriosiscono!"
        case .seen:
            return "Quando finisci un film, segnalo come visto: lo ritroverai qui e non te lo riproporremo."
        }
    }
}

#Preview {
    MyListView()
        .environment(MovieLibrary())
}
