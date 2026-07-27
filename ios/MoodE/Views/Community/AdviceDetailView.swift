//
//  AdviceDetailView.swift
//  MoodE
//

import SwiftUI

/// Detail of an advice request: the question plus every movie suggestion.
/// The requester can mark replies as helpful; everyone else can suggest
/// a movie through TMDB search.
struct AdviceDetailView: View {
    let request: AdviceRequest

    @Environment(MoodDiary.self) private var diary
    @Environment(\.dismiss) private var dismiss
    @State private var detail: AdviceDetail?
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var showSuggestSheet: Bool = false
    @State private var helpfulTrigger: Bool = false
    @State private var showDeleteRequestConfirm: Bool = false
    @State private var replyToDelete: AdviceReply?
    @State private var showDeleteReplyConfirm: Bool = false

    private var community: CommunityService { CommunityService.shared }

    private var displayRequest: AdviceRequest { detail?.request ?? request }
    private var replies: [AdviceReply] { detail?.replies ?? [] }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    AdviceRequestCard(
                        request: displayRequest,
                        onDelete: displayRequest.isMine ? { showDeleteRequestConfirm = true } : nil
                    )

                    if !displayRequest.isMine {
                        suggestButton
                    }

                    Text(L("advice.detail.repliesHeader"))
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                        .padding(.top, 4)

                    repliesContent
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .refreshable { await load() }
        }
        .navigationTitle(L("advice.detail.title"))
        .toolbarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(isPresented: $showSuggestSheet) {
            AdviceSuggestSheet(requestId: displayRequest.id) {
                Task { await load() }
            }
        }
        .sensoryFeedback(.success, trigger: helpfulTrigger)
        .alert(L("delete.request.title"), isPresented: $showDeleteRequestConfirm) {
            Button(L("common.delete"), role: .destructive) { deleteRequest() }
            Button(L("common.cancel"), role: .cancel) {}
        } message: {
            Text(displayRequest.replyCount > 0 ? L("delete.request.msgWithReplies") : L("delete.request.msg"))
        }
        .alert(
            L("delete.reply.title"),
            isPresented: $showDeleteReplyConfirm,
            presenting: replyToDelete
        ) { reply in
            Button(L("common.delete"), role: .destructive) { deleteReply(reply) }
            Button(L("common.cancel"), role: .cancel) {}
        } message: { _ in
            Text(L("delete.reply.msg"))
        }
    }

    // MARK: - Replies

    @ViewBuilder
    private var repliesContent: some View {
        if isLoading && detail == nil {
            VStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Theme.card)
                        .frame(height: 96)
                        .shimmer()
                }
            }
        } else if let errorMessage, detail == nil {
            VStack(spacing: 10) {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                Button(L("common.retry")) {
                    Task { await load() }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.tabTrending)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        } else if replies.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "popcorn")
                    .font(.system(size: 30))
                    .foregroundStyle(Theme.tabTrending.opacity(0.5))
                Text(L("advice.detail.noReplies"))
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        } else {
            LazyVStack(spacing: 12) {
                ForEach(replies) { reply in
                    AdviceReplyCard(
                        reply: reply,
                        canMarkHelpful: displayRequest.isMine && !reply.isMine,
                        onHelpful: { markHelpful(reply) },
                        onReport: reply.isMine ? nil : {
                            Task { await community.report(targetType: "reply", targetId: reply.id) }
                            hideReply(reply)
                        },
                        onHide: reply.isMine ? nil : { hideReply(reply) },
                        onDelete: reply.isMine ? {
                            replyToDelete = reply
                            showDeleteReplyConfirm = true
                        } : nil
                    )
                }
            }
            .animation(.spring(duration: 0.3), value: replies)
        }
    }

    private var suggestButton: some View {
        Button {
            showSuggestSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "film.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text(L("advice.suggest"))
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Theme.tabTrending, in: .rect(cornerRadius: 14))
        }
        .buttonStyle(PressableCardStyle())
    }

    // MARK: - Actions

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            detail = try await community.loadDetail(id: request.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func markHelpful(_ reply: AdviceReply) {
        guard !reply.markedHelpful else { return }
        Task {
            do {
                try await community.markHelpful(replyId: reply.id)
                helpfulTrigger.toggle()
                diary.recordCommunityAction()
                await load()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func hideReply(_ reply: AdviceReply) {
        community.hide(id: reply.id)
        guard let current = detail else { return }
        withAnimation(.spring(duration: 0.3)) {
            detail = AdviceDetail(
                request: current.request,
                replies: current.replies.filter { $0.id != reply.id }
            )
        }
    }

    /// Deletes MY request (server re-checks authorship) and leaves the page.
    private func deleteRequest() {
        Task {
            do {
                try await community.deleteRequest(id: displayRequest.id)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Deletes MY reply and removes it from the list right away.
    private func deleteReply(_ reply: AdviceReply) {
        Task {
            do {
                try await community.deleteReply(id: reply.id)
                guard let current = detail else { return }
                withAnimation(.spring(duration: 0.3)) {
                    detail = AdviceDetail(
                        request: current.request,
                        replies: current.replies.filter { $0.id != reply.id }
                    )
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

/// Card for a movie suggestion under a request.
struct AdviceReplyCard: View {
    let reply: AdviceReply
    let canMarkHelpful: Bool
    var onHelpful: (() -> Void)? = nil
    var onReport: (() -> Void)? = nil
    var onHide: (() -> Void)? = nil
    /// Shown only for the author's own reply ("Elimina" in the menu).
    var onDelete: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(reply.isMine ? L("advice.mine") : reply.nickname)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(reply.isMine ? Theme.tabTrending : Theme.inkSoft)
                Text(relativeTime)
                    .font(.caption2)
                    .foregroundStyle(Theme.inkSoft.opacity(0.7))
                Spacer()
                if onReport != nil || onHide != nil || onDelete != nil {
                    Menu {
                        if let onDelete {
                            Button(role: .destructive, action: onDelete) {
                                Label(L("common.delete"), systemImage: "trash")
                            }
                        }
                        if let onReport {
                            Button(role: .destructive, action: onReport) {
                                Label(L("advice.report"), systemImage: "flag")
                            }
                        }
                        if let onHide {
                            Button(action: onHide) {
                                Label(L("advice.hide"), systemImage: "eye.slash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.inkSoft)
                            .frame(width: 26, height: 26)
                            .contentShape(.rect)
                    }
                }
            }

            HStack(spacing: 12) {
                poster

                VStack(alignment: .leading, spacing: 4) {
                    Text(reply.movieTitle)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                    if let text = reply.text, !text.isEmpty {
                        Text(text)
                            .font(.footnote)
                            .foregroundStyle(Theme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }

            HStack {
                if canMarkHelpful || reply.markedHelpful {
                    Button {
                        onHelpful?()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: reply.markedHelpful ? "hand.thumbsup.fill" : "hand.thumbsup")
                                .font(.system(size: 12, weight: .semibold))
                            Text(L("advice.helpful"))
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(reply.markedHelpful ? .white : Theme.seenGreen)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            reply.markedHelpful ? Theme.seenGreen : Theme.seenGreen.opacity(0.12),
                            in: .capsule
                        )
                    }
                    .buttonStyle(PressableCardStyle())
                    .disabled(reply.markedHelpful || !canMarkHelpful)
                }

                Spacer()

                if reply.helpfulCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.system(size: 10, weight: .semibold))
                        Text("\(reply.helpfulCount)")
                            .font(.caption.weight(.bold))
                            .monospacedDigit()
                    }
                    .foregroundStyle(Theme.seenGreen)
                }
            }
        }
        .padding(13)
        .background(Theme.card, in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.ink.opacity(0.06), lineWidth: 1)
        )
    }

    private var poster: some View {
        Group {
            if let url = reply.posterURL {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Theme.surface
                }
            } else {
                Theme.surface.overlay {
                    Image(systemName: "film")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.inkSoft.opacity(0.5))
                }
            }
        }
        .frame(width: 46, height: 69)
        .clipShape(.rect(cornerRadius: 8))
    }

    private var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = LocalizationManager.shared.locale
        formatter.unitsStyle = .short
        return formatter.localizedString(for: reply.date, relativeTo: Date())
    }
}

/// Sheet to suggest a movie: TMDB search + optional short comment.
struct AdviceSuggestSheet: View {
    let requestId: String
    var onSent: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(MoodDiary.self) private var diary

    @State private var query: String = ""
    @State private var results: [TMDBMovie] = []
    @State private var isSearching: Bool = false
    @State private var hasSearched: Bool = false
    @State private var selectedMovie: TMDBMovie?
    @State private var comment: String = ""
    @State private var isSending: Bool = false
    @State private var errorMessage: String?
    @FocusState private var searchFocused: Bool

    private var community: CommunityService { CommunityService.shared }
    private let maxComment = 200

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 12) {
                    if let movie = selectedMovie {
                        selectedSection(movie)
                    } else {
                        searchSection
                    }
                }
                .padding(.top, 10)
            }
            .navigationTitle(L("advice.suggest.title"))
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

    // MARK: - Search step

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
                    .stroke(Theme.tabTrending.opacity(0.18), lineWidth: 1)
            )
            .padding(.horizontal, 20)

            if isSearching {
                ProgressView()
                    .tint(Theme.tabTrending)
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
                        Button {
                            selectedMovie = movie
                        } label: {
                            HStack(spacing: 12) {
                                moviePoster(movie.posterURL)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(movie.title)
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(Theme.ink)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    if let year = movie.releaseYear {
                                        Text(year)
                                            .font(.caption)
                                            .foregroundStyle(Theme.inkSoft)
                                    }
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(Theme.tabTrending)
                            }
                            .padding(10)
                            .background(Theme.card, in: .rect(cornerRadius: 14))
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
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

    // MARK: - Confirm step

    private func selectedSection(_ movie: TMDBMovie) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    moviePoster(movie.posterURL)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(movie.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.ink)
                        if let year = movie.releaseYear {
                            Text(year)
                                .font(.caption)
                                .foregroundStyle(Theme.inkSoft)
                        }
                    }
                    Spacer()
                    Button {
                        selectedMovie = nil
                        comment = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 19))
                            .foregroundStyle(Theme.inkSoft.opacity(0.6))
                    }
                }
                .padding(12)
                .background(Theme.card, in: .rect(cornerRadius: 16))

                VStack(alignment: .trailing, spacing: 4) {
                    TextField(L("advice.suggest.commentPlaceholder"), text: $comment, axis: .vertical)
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink)
                        .lineLimit(3...6)
                        .padding(12)
                        .background(Theme.card, in: .rect(cornerRadius: 14))
                        .onChange(of: comment) { _, newValue in
                            if newValue.count > maxComment {
                                comment = String(newValue.prefix(maxComment))
                            }
                        }
                    Text("\(comment.count)/\(maxComment)")
                        .font(.caption2)
                        .foregroundStyle(Theme.inkSoft)
                        .monospacedDigit()
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(Theme.rose)
                }

                Button {
                    send(movie: movie)
                } label: {
                    HStack(spacing: 8) {
                        if isSending {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        Text(L("advice.suggest.send"))
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Theme.tabTrending, in: .rect(cornerRadius: 14))
                }
                .disabled(isSending)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    private func moviePoster(_ url: URL?) -> some View {
        Group {
            if let url {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Theme.surface
                }
            } else {
                Theme.surface.overlay {
                    Image(systemName: "film")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.inkSoft.opacity(0.5))
                }
            }
        }
        .frame(width: 42, height: 63)
        .clipShape(.rect(cornerRadius: 8))
    }

    // MARK: - Logic

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func send(movie: TMDBMovie) {
        errorMessage = nil
        isSending = true
        Task {
            defer { isSending = false }
            do {
                _ = try await community.sendReply(
                    requestId: requestId,
                    movie: movie,
                    text: comment.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                diary.recordCommunityAction()
                onSent()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
