//
//  StatusComposerView.swift
//  MoodE
//

import SwiftUI

/// Sheet to publish an ephemeral "Stato Mood": pick a movie from the
/// watched list or via TMDB search, add an optional short comment
/// (max 150 chars, profanity-filtered), publish anonymously for 24h.
/// The visual card is always generated from the TMDB poster + title:
/// the user never uploads personal photos or videos.
struct StatusComposerView: View {
    var onPublished: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(MovieLibrary.self) private var library

    @State private var selectedMovie: TMDBMovie?
    @State private var searchQuery: String = ""
    @State private var searchResults: [TMDBMovie] = []
    @State private var isSearching: Bool = false
    @State private var hasSearched: Bool = false
    @State private var text: String = ""
    @State private var isPublishing: Bool = false
    @State private var errorMessage: String?
    @FocusState private var searchFocused: Bool
    @FocusState private var textFocused: Bool

    private var service: StatusService { StatusService.shared }
    private let maxLength = 150

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(L("status.composer.movieLabel"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.ink)

                        if let selectedMovie {
                            selectedCard(selectedMovie)
                        }

                        watchedRow

                        searchSection

                        commentSection

                        if let errorMessage {
                            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                                .font(.footnote)
                                .foregroundStyle(Theme.rose)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(LF("status.composer.anon", CommunityService.shared.nickname))
                            Text(L("status.composer.expiry"))
                        }
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)

                        publishButton
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(L("status.composer.title"))
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
    }

    // MARK: - Selected movie

    private func selectedCard(_ movie: TMDBMovie) -> some View {
        HStack(spacing: 12) {
            posterThumb(url: movie.posterURL, width: 52, height: 78)

            VStack(alignment: .leading, spacing: 3) {
                Text(movie.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                Label(L("status.composer.title"), systemImage: "clock.badge.checkmark")
                    .font(.caption2)
                    .foregroundStyle(Theme.tabTrending)
            }

            Spacer()

            Button {
                selectedMovie = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.inkSoft.opacity(0.6))
            }
        }
        .padding(12)
        .background(Theme.cardStrong, in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.tabTrending.opacity(0.4), lineWidth: 1.5)
        )
    }

    // MARK: - Watched list

    @ViewBuilder
    private var watchedRow: some View {
        let watched = library.watched
        if !watched.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(L("status.composer.watched"))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.inkSoft)

                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(watched) { entry in
                            watchedPoster(entry)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        } else {
            Text(L("status.composer.noWatched"))
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
        }
    }

    private func watchedPoster(_ entry: LibraryEntry) -> some View {
        let isSelected = selectedMovie?.id == entry.id
        return Button {
            selectedMovie = entry.asMovie
            errorMessage = nil
        } label: {
            VStack(spacing: 5) {
                posterThumb(url: entry.posterURL, width: 66, height: 99)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                isSelected ? Theme.tabTrending : .clear,
                                lineWidth: 2.5
                            )
                    )
                Text(entry.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isSelected ? Theme.tabTrending : Theme.inkSoft)
                    .lineLimit(1)
                    .frame(width: 66)
            }
        }
        .buttonStyle(PressableCardStyle())
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    // MARK: - TMDB search

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("status.composer.search"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.inkSoft)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                TextField(L("status.composer.searchPlaceholder"), text: $searchQuery)
                    .font(.subheadline)
                    .focused($searchFocused)
                    .submitLabel(.search)
                    .onSubmit { runSearch() }
                if isSearching {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(Theme.card, in: .rect(cornerRadius: 14))

            if hasSearched && searchResults.isEmpty && !isSearching {
                Text(L("status.composer.searchEmpty"))
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
            }

            ForEach(searchResults.prefix(6)) { movie in
                searchRow(movie)
            }
        }
    }

    private func searchRow(_ movie: TMDBMovie) -> some View {
        let isSelected = selectedMovie?.id == movie.id
        return Button {
            selectedMovie = movie
            errorMessage = nil
            searchFocused = false
        } label: {
            HStack(spacing: 10) {
                posterThumb(url: movie.posterURL, width: 36, height: 54)
                Text(movie.title)
                    .font(.subheadline.weight(isSelected ? .bold : .regular))
                    .foregroundStyle(isSelected ? Theme.tabTrending : Theme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.tabTrending)
                }
            }
            .padding(8)
            .background(Theme.card, in: .rect(cornerRadius: 12))
        }
        .buttonStyle(PressableCardStyle())
    }

    private func runSearch() {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        isSearching = true
        Task {
            defer {
                isSearching = false
                hasSearched = true
            }
            searchResults = (try? await TMDBService.searchMovies(query: query)) ?? []
        }
    }

    // MARK: - Comment

    private var commentSection: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack {
                Text(L("status.composer.commentLabel"))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.inkSoft)
                Spacer()
            }

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(L("status.composer.placeholder"))
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft.opacity(0.6))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                }
                TextEditor(text: $text)
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                    .focused($textFocused)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 80)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .onChange(of: text) { _, newValue in
                        if newValue.count > maxLength {
                            text = String(newValue.prefix(maxLength))
                        }
                    }
            }
            .background(Theme.card, in: .rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.tabTrending.opacity(0.2), lineWidth: 1)
            )

            Text("\(text.count)/\(maxLength)")
                .font(.caption2)
                .foregroundStyle(text.count >= maxLength ? Theme.rose : Theme.inkSoft)
                .monospacedDigit()
        }
    }

    // MARK: - Publish

    private var publishButton: some View {
        Button {
            publish()
        } label: {
            HStack(spacing: 8) {
                if isPublishing {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(L("status.composer.publish"))
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(
                selectedMovie != nil ? Theme.tabTrending : Theme.tabTrending.opacity(0.35),
                in: .rect(cornerRadius: 14)
            )
        }
        .disabled(isPublishing)
        .sensoryFeedback(.success, trigger: isPublishing)
    }

    private func publish() {
        textFocused = false
        searchFocused = false
        guard let movie = selectedMovie else {
            errorMessage = L("status.composer.needMovie")
            return
        }
        errorMessage = nil
        isPublishing = true
        Task {
            defer { isPublishing = false }
            do {
                _ = try await service.publish(
                    movie: movie,
                    text: text.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                onPublished()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Shared pieces

    private func posterThumb(url: URL?, width: CGFloat, height: CGFloat) -> some View {
        Color.clear
            .overlay {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        ZStack {
                            Theme.card
                            Image(systemName: "film")
                                .font(.system(size: width * 0.3))
                                .foregroundStyle(Theme.inkSoft.opacity(0.5))
                        }
                    }
                }
                .allowsHitTesting(false)
            }
            .frame(width: width, height: height)
            .clipShape(.rect(cornerRadius: 10))
    }
}
