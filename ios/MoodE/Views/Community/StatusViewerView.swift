//
//  StatusViewerView.swift
//  MoodE
//

import Combine
import SwiftUI

/// Full-screen story-style viewer for "Stato Mood" statuses.
/// Auto-advances every few seconds with progress bars on top; tap the
/// left/right side of the poster to move between statuses. Viewers can
/// leave short public comments or quick emoji reactions; the owner sees
/// view/reaction insights instead (anonymous nicknames only).
struct StatusViewerView: View {
    let onClosed: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var groups: [StatusGroup]
    @State private var groupIndex: Int
    @State private var itemIndex: Int = 0
    @State private var progress: Double = 0

    @State private var comments: [StatusComment] = []
    @State private var commentText: String = ""
    @State private var isSendingComment: Bool = false
    @State private var commentError: String?
    @State private var showInsights: Bool = false
    @State private var insights: StatusInsights?
    @FocusState private var commentFocused: Bool

    private var service: StatusService { StatusService.shared }
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    private let itemDuration: Double = 6

    init(groups: [StatusGroup], startGroupIndex: Int, onClosed: @escaping () -> Void) {
        self.onClosed = onClosed
        _groups = State(initialValue: groups)
        _groupIndex = State(initialValue: min(max(startGroupIndex, 0), max(groups.count - 1, 0)))
    }

    private var currentGroup: StatusGroup? {
        groups.indices.contains(groupIndex) ? groups[groupIndex] : nil
    }

    private var currentItem: MoodStatusItem? {
        guard let group = currentGroup, group.statuses.indices.contains(itemIndex) else { return nil }
        return group.statuses[itemIndex]
    }

    private var isPaused: Bool {
        commentFocused || showInsights
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let group = currentGroup, let item = currentItem {
                VStack(spacing: 0) {
                    progressBars(for: group)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    header(group: group, item: item)
                        .padding(.horizontal, 16)
                        .padding(.top, 10)

                    storyCard(item: item)
                        .padding(.horizontal, 24)
                        .padding(.top, 12)

                    commentsPreview
                        .padding(.horizontal, 24)
                        .padding(.top, 10)

                    bottomBar(group: group, item: item)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                }
            }
        }
        .onReceive(timer) { _ in
            guard !isPaused else { return }
            progress += 0.05 / itemDuration
            if progress >= 1 { advance() }
        }
        .task(id: "\(groupIndex)-\(itemIndex)") {
            await showCurrentItem()
        }
        .sheet(isPresented: $showInsights) {
            insightsSheet
        }
        .onDisappear { onClosed() }
    }

    // MARK: - Progress + header

    private func progressBars(for group: StatusGroup) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(group.statuses.enumerated()), id: \.element.id) { index, _ in
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.25))
                        Capsule()
                            .fill(.white)
                            .frame(width: geo.size.width * barFill(index))
                    }
                }
                .frame(height: 3)
            }
        }
    }

    private func barFill(_ index: Int) -> CGFloat {
        if index < itemIndex { return 1 }
        if index == itemIndex { return CGFloat(min(progress, 1)) }
        return 0
    }

    private func header(group: StatusGroup, item: MoodStatusItem) -> some View {
        HStack(spacing: 10) {
            StatusAvatarView(nickname: group.nickname, size: 36)

            VStack(alignment: .leading, spacing: 1) {
                Text(group.isMine ? L("advice.mine") : group.nickname)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white)
                HStack(spacing: 6) {
                    Text(relativeTime(item.date))
                    Text("·")
                    Text(LF("status.viewer.expires", remainingTime(until: item.expiryDate)))
                }
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.65))
            }

            Spacer()

            if !group.isMine {
                Menu {
                    Button(role: .destructive) {
                        reportCurrentStatus(item)
                    } label: {
                        Label(L("advice.report"), systemImage: "flag")
                    }
                    Button {
                        hideCurrentStatus(item)
                    } label: {
                        Label(L("advice.hide"), systemImage: "eye.slash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 34, height: 34)
                        .contentShape(.rect)
                }
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 34, height: 34)
                    .contentShape(.rect)
            }
        }
    }

    // MARK: - Story card

    private func storyCard(item: MoodStatusItem) -> some View {
        GeometryReader { geo in
            VStack(spacing: 12) {
                Color.clear
                    .overlay {
                        AsyncImage(url: item.posterURL) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().aspectRatio(contentMode: .fill)
                            default:
                                ZStack {
                                    Color.white.opacity(0.08)
                                    Image(systemName: "film")
                                        .font(.system(size: 44))
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                            }
                        }
                        .allowsHitTesting(false)
                    }
                    .frame(maxHeight: geo.size.height * 0.72)
                    .clipShape(.rect(cornerRadius: 22))

                Text(item.movieTitle)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                if let mood = item.moodTag {
                    HStack(spacing: 5) {
                        Image(systemName: mood.icon)
                            .font(.system(size: 11, weight: .semibold))
                        Text(mood.title)
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 11)
                    .frame(height: 26)
                    .background(mood.tint.opacity(0.85), in: .capsule)
                }

                if let text = item.text, !text.isEmpty {
                    Text(text)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(.white.opacity(0.12), in: .rect(cornerRadius: 14))
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
            .onTapGesture(coordinateSpace: .local) { location in
                if location.x < geo.size.width / 3 {
                    goBack()
                } else {
                    advance()
                }
            }
        }
    }

    // MARK: - Comments

    @ViewBuilder
    private var commentsPreview: some View {
        if !comments.isEmpty {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(comments) { comment in
                        commentRow(comment)
                    }
                }
            }
            .frame(maxHeight: 96)
            .scrollIndicators(.hidden)
        }
    }

    private func commentRow(_ comment: StatusComment) -> some View {
        HStack(alignment: .top, spacing: 8) {
            StatusAvatarView(nickname: comment.nickname, size: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(comment.isMine ? L("advice.mine") : comment.nickname)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.75))
                Text(comment.text)
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .contextMenu {
            if !comment.isMine {
                Button(role: .destructive) {
                    Task { await service.report(targetType: "comment", targetId: comment.id) }
                    service.hide(id: comment.id)
                    comments.removeAll { $0.id == comment.id }
                } label: {
                    Label(L("advice.report"), systemImage: "flag")
                }
                Button {
                    service.hide(id: comment.id)
                    comments.removeAll { $0.id == comment.id }
                } label: {
                    Label(L("advice.hide"), systemImage: "eye.slash")
                }
            }
        }
    }

    // MARK: - Bottom bar

    @ViewBuilder
    private func bottomBar(group: StatusGroup, item: MoodStatusItem) -> some View {
        if group.isMine {
            ownerBar(item: item)
        } else {
            viewerBar(item: item)
        }
    }

    /// Owner sees view count and can open the full activity recap.
    private func ownerBar(item: MoodStatusItem) -> some View {
        Button {
            showInsights = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text(viewsLabel(item.viewCount ?? 0))
                    .font(.footnote.weight(.semibold))
                Spacer()
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 13, weight: .semibold))
                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(.white.opacity(0.14), in: .capsule)
        }
        .buttonStyle(PressableCardStyle())
    }

    /// Viewers get quick emoji reactions plus a short comment field.
    private func viewerBar(item: MoodStatusItem) -> some View {
        VStack(spacing: 8) {
            if let commentError {
                Text(commentError)
                    .font(.caption)
                    .foregroundStyle(Theme.rose)
            }

            HStack(spacing: 8) {
                ForEach(StatusService.allowedReactions, id: \.self) { emoji in
                    reactionButton(emoji: emoji, item: item)
                }

                TextField(L("status.viewer.commentPlaceholder"), text: $commentText)
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .tint(.white)
                    .focused($commentFocused)
                    .submitLabel(.send)
                    .onSubmit { sendComment(item: item) }
                    .onChange(of: commentText) { _, newValue in
                        if newValue.count > 100 {
                            commentText = String(newValue.prefix(100))
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                    .background(.white.opacity(0.14), in: .capsule)

                if isSendingComment {
                    ProgressView().tint(.white)
                } else if !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        sendComment(item: item)
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Theme.tabTrending, in: .circle)
                    }
                }
            }
        }
    }

    private func reactionButton(emoji: String, item: MoodStatusItem) -> some View {
        let isMine = item.myReaction == emoji
        let count = item.reactionCounts[emoji] ?? 0
        return Button {
            sendReaction(emoji: emoji, item: item)
        } label: {
            VStack(spacing: 0) {
                ReactionGlyph(emoji: emoji, size: 17)
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                        .monospacedDigit()
                }
            }
            .frame(width: 38, height: 40)
            .background(
                isMine ? Theme.tabTrending.opacity(0.85) : .white.opacity(0.14),
                in: .circle
            )
        }
        .buttonStyle(PressableCardStyle())
        .sensoryFeedback(.impact(weight: .light), trigger: isMine)
    }

    // MARK: - Insights sheet (owner only)

    private var insightsSheet: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let insights {
                            HStack(spacing: 12) {
                                insightBadge(
                                    icon: "eye.fill",
                                    value: "\(insights.viewCount)",
                                    label: viewsLabel(insights.viewCount)
                                )
                                insightBadge(
                                    icon: "bubble.left.fill",
                                    value: "\(insights.commentCount)",
                                    label: L("status.insights.commentCount")
                                )
                            }

                            Text(L("status.insights.reactions"))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Theme.ink)

                            if insights.reactions.isEmpty {
                                Text(L("status.insights.noReactions"))
                                    .font(.footnote)
                                    .foregroundStyle(Theme.inkSoft)
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(insights.reactions) { reaction in
                                        HStack(spacing: 10) {
                                            StatusAvatarView(nickname: reaction.nickname, size: 30)
                                            Text(reaction.nickname)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(Theme.ink)
                                            Spacer()
                                            ReactionGlyph(emoji: reaction.emoji, size: 18)
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 9)
                                        .background(Theme.card, in: .rect(cornerRadius: 14))
                                    }
                                }
                            }
                        } else {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(L("status.insights.title"))
            .toolbarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
        .task {
            guard let item = currentItem else { return }
            insights = try? await service.loadInsights(statusId: item.id)
        }
        .onDisappear { insights = nil }
    }

    private func insightBadge(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.tabTrending)
            Text(value)
                .font(.title3.weight(.heavy))
                .foregroundStyle(Theme.ink)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Theme.card, in: .rect(cornerRadius: 16))
    }

    // MARK: - Navigation & data

    private func advance() {
        progress = 0
        commentFocused = false
        guard let group = currentGroup else { return dismiss() }
        if itemIndex + 1 < group.statuses.count {
            itemIndex += 1
        } else if groupIndex + 1 < groups.count {
            groupIndex += 1
            itemIndex = 0
        } else {
            dismiss()
        }
    }

    private func goBack() {
        progress = 0
        commentFocused = false
        if itemIndex > 0 {
            itemIndex -= 1
        } else if groupIndex > 0 {
            groupIndex -= 1
            itemIndex = max(groups[groupIndex].statuses.count - 1, 0)
        }
    }

    /// Loads comments and records the view for the newly shown status.
    private func showCurrentItem() async {
        progress = 0
        comments = []
        commentError = nil
        commentText = ""
        guard let group = currentGroup, let item = currentItem else { return }

        if !group.isMine {
            markSeenLocally(statusId: item.id)
            Task { await service.markViewed(statusId: item.id) }
        }
        comments = (try? await service.loadComments(statusId: item.id)) ?? []
    }

    private func markSeenLocally(statusId: String) {
        guard groups.indices.contains(groupIndex) else { return }
        guard let index = groups[groupIndex].statuses.firstIndex(where: { $0.id == statusId }) else { return }
        groups[groupIndex].statuses[index].seen = true
    }

    private func sendReaction(emoji: String, item: MoodStatusItem) {
        Task {
            guard let result = try? await service.react(statusId: item.id, emoji: emoji) else { return }
            guard groups.indices.contains(groupIndex),
                  let index = groups[groupIndex].statuses.firstIndex(where: { $0.id == item.id }) else { return }
            groups[groupIndex].statuses[index].myReaction = result.myReaction
            groups[groupIndex].statuses[index].reactionCounts = result.counts
        }
    }

    private func sendComment(item: MoodStatusItem) {
        let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSendingComment else { return }
        isSendingComment = true
        commentError = nil
        Task {
            defer { isSendingComment = false }
            do {
                let comment = try await service.sendComment(statusId: item.id, text: trimmed)
                comments.append(comment)
                commentText = ""
                commentFocused = false
            } catch {
                commentError = error.localizedDescription
            }
        }
    }

    private func reportCurrentStatus(_ item: MoodStatusItem) {
        Task { await service.report(targetType: "status", targetId: item.id) }
        hideCurrentStatus(item)
    }

    private func hideCurrentStatus(_ item: MoodStatusItem) {
        service.hide(id: item.id)
        guard groups.indices.contains(groupIndex) else { return dismiss() }
        groups[groupIndex].statuses.removeAll { $0.id == item.id }
        if groups[groupIndex].statuses.isEmpty {
            groups.remove(at: groupIndex)
            if groups.isEmpty { return dismiss() }
            if groupIndex >= groups.count { groupIndex = groups.count - 1 }
            itemIndex = 0
        } else if itemIndex >= groups[groupIndex].statuses.count {
            itemIndex = groups[groupIndex].statuses.count - 1
        }
        progress = 0
    }

    // MARK: - Formatting

    private func viewsLabel(_ count: Int) -> String {
        count == 1 ? L("status.viewer.views.one") : LF("status.viewer.views.many", count)
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = LocalizationManager.shared.locale
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func remainingTime(until date: Date) -> String {
        let seconds = max(date.timeIntervalSinceNow, 0)
        let hours = Int(seconds) / 3600
        if hours >= 1 { return "\(hours)h" }
        return "\(max(Int(seconds) / 60, 1))m"
    }
}

/// Emoji reaction glyph with an SF Symbol fallback for devices where
/// color emoji rendering is unavailable.
struct ReactionGlyph: View {
    let emoji: String
    let size: CGFloat

    var body: some View {
        if EmojiSupport.isAvailable {
            Text(emoji).font(.system(size: size))
        } else {
            Image(systemName: symbolName)
                .font(.system(size: size * 0.9, weight: .semibold))
                .foregroundStyle(symbolColor)
        }
    }

    private var symbolName: String {
        switch emoji {
        case "❤️": return "heart.fill"
        case "🔥": return "flame.fill"
        case "😂": return "face.smiling.inverse"
        case "👀": return "eye.fill"
        default: return "hand.thumbsup.fill"
        }
    }

    private var symbolColor: Color {
        switch emoji {
        case "❤️": return .red
        case "🔥": return .orange
        case "😂": return .yellow
        case "👀": return .cyan
        default: return .white
        }
    }
}
