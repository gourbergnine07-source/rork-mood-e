//
//  MemoriesView.swift
//  MoodE
//

import SwiftUI
import UIKit

/// "I miei ricordi cinematografici": reverse-chronological gallery of
/// watched planned movies with emoji rating, comment and share card.
struct MemoriesView: View {
    @Environment(MoviePlanner.self) private var planner

    @State private var sharePayload: ShareCardPayload?
    @State private var renderingId: UUID?
    @State private var pendingDeletion: MovieMemory?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if planner.memories.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(planner.sortedMemories) { memory in
                            MemoryRow(
                                memory: memory,
                                isRendering: renderingId == memory.id,
                                onShare: { share(memory) },
                                onDelete: { pendingDeletion = memory }
                            )
                            .contextMenu {
                                Button(role: .destructive) {
                                    pendingDeletion = memory
                                } label: {
                                    Label(L("common.delete"), systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle(L("memories.title"))
        .toolbarTitleDisplayMode(.inline)
        .sheet(item: $sharePayload) { payload in
            ShareCardSheet(payload: payload)
        }
        .alert(
            L("diary.movie.remove.title"),
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { isPresented in
                    if !isPresented { pendingDeletion = nil }
                }
            ),
            presenting: pendingDeletion
        ) { memory in
            Button(L("common.cancel"), role: .cancel) { pendingDeletion = nil }
            Button(L("diary.movie.remove.confirm"), role: .destructive) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    planner.removeMemory(memory.id)
                }
                pendingDeletion = nil
            }
        } message: { _ in
            Text(L("diary.movie.remove.msg"))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("🎞️")
                .font(.system(size: 48))
            Text(L("memories.empty.title"))
                .font(.headline)
                .foregroundStyle(Theme.ink)
            Text(L("memories.empty.msg"))
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
    }

    /// Downloads the poster (if any), renders the memory card on device
    /// and opens the preview + share sheet.
    private func share(_ memory: MovieMemory) {
        guard renderingId == nil else { return }
        renderingId = memory.id
        Task {
            var poster: UIImage?
            if let url = memory.posterURL,
               let (data, _) = try? await URLSession.shared.data(from: url) {
                poster = UIImage(data: data)
            }
            let card = MemoryShareCardView(memory: memory, poster: poster)
            if let image = ShareCardRenderer.render(card) {
                sharePayload = ShareCardPayload(image: image, title: memory.title)
            }
            renderingId = nil
        }
    }
}

/// One memory entry: poster, title, watch date, emoji rating and comment.
private struct MemoryRow: View {
    let memory: MovieMemory
    let isRendering: Bool
    let onShare: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            NavigationLink(value: memory.asMovie) {
                HStack(alignment: .top, spacing: 12) {
                    poster

                    VStack(alignment: .leading, spacing: 4) {
                        Text(memory.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.ink)
                            .underline(true, color: Theme.primary.opacity(0.4))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        HStack(spacing: 6) {
                            Text(memory.ratingEmoji)
                                .font(.system(size: 17))
                            Text(dateString)
                                .font(.caption)
                                .foregroundStyle(Theme.inkSoft)
                        }

                        if let comment = memory.comment {
                            HStack(alignment: .top, spacing: 6) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Theme.rose.opacity(0.5))
                                    .frame(width: 3)
                                Text(comment)
                                    .font(.footnote.italic())
                                    .foregroundStyle(Theme.ink.opacity(0.85))
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(.top, 2)
                        }

                        // The emotional route that led to this movie, kept
                        // next to the rating and the comment so the memory
                        // tells the whole story: before and after watching.
                        if let discoveryPath = DiscoveryPathStore.shared.path(for: memory.movieId) {
                            DiscoveryPathView(path: discoveryPath)
                                .padding(.top, 3)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(DiaryLinkButtonStyle(accent: Theme.primary))
            .accessibilityHint(L("diary.movie.open"))

            DiaryMovieMenu(onDelete: onDelete)

            Button(action: onShare) {
                Group {
                    if isRendering {
                        ProgressView()
                            .tint(Theme.primary)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.primary)
                    }
                }
                .frame(width: 32, height: 32)
                .background(Theme.primary.opacity(0.10), in: .circle)
                .overlay(
                    Circle().stroke(Theme.primary.opacity(0.35), lineWidth: 1)
                )
                .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .disabled(isRendering)
            .accessibilityLabel(L("memories.share"))
        }
        .padding(12)
        .background(Theme.card, in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.primary.opacity(0.10), lineWidth: 1)
        )
    }

    private var poster: some View {
        Group {
            if let url = memory.posterURL {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Theme.surface
                }
            } else {
                Theme.surface.overlay { Text("🎬") }
            }
        }
        .frame(width: 56, height: 84)
        .clipShape(.rect(cornerRadius: 10))
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.locale = LocalizationManager.shared.locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: memory.watchedDate)
    }
}

#Preview {
    NavigationStack {
        MemoriesView()
    }
    .environment(MoviePlanner())
}
