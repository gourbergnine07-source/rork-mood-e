//
//  AdviceBoardView.swift
//  MoodE
//

import SwiftUI

/// "Consigli" community board: anonymous advice requests between users.
/// Embedded inside the Tendenze tab's NavigationStack.
struct AdviceBoardView: View {
    private var community: CommunityService { CommunityService.shared }

    @State private var requests: [AdviceRequest] = []
    @State private var stats: AdviceStats?
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var filterMood: Mood?
    @State private var showComposer: Bool = false
    @State private var hasLoaded: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if !community.hasSeenPrivacyNotice {
                    privacyNotice
                        .padding(.horizontal, 24)
                }

                askButton
                    .padding(.horizontal, 24)

                if let stats, !stats.moods.isEmpty {
                    MoodStatsCard(stats: stats)
                        .padding(.horizontal, 24)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                moodFilter

                content
            }
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .refreshable { await load() }
        .task {
            guard !hasLoaded else { return }
            hasLoaded = true
            await load()
        }
        .onChange(of: filterMood) { _, _ in
            Task { await load() }
        }
        .sheet(isPresented: $showComposer) {
            AdviceComposerView { newRequest in
                requests.insert(newRequest, at: 0)
            }
        }
    }

    // MARK: - Sections

    private var privacyNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "theatermask.and.paintbrush.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.tabTrending)
                Text(L("advice.privacy.title"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.ink)
            }
            Text(L("advice.privacy.msg"))
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    community.dismissPrivacyNotice()
                }
            } label: {
                Text(L("advice.privacy.ok"))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(Theme.tabTrending, in: .capsule)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.tabTrending.opacity(0.10), in: .rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Theme.tabTrending.opacity(0.25), lineWidth: 1)
        )
    }

    private var askButton: some View {
        Button {
            showComposer = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.bubble.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text(L("advice.ask"))
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Theme.tabTrending, in: .rect(cornerRadius: 14))
        }
        .buttonStyle(PressableCardStyle())
        .sensoryFeedback(.impact(weight: .light), trigger: showComposer)
    }

    private var moodFilter: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                filterChip(title: L("advice.filter.all"), emoji: nil, icon: "sparkles", isSelected: filterMood == nil) {
                    filterMood = nil
                }
                ForEach(Mood.allCases) { mood in
                    filterChip(
                        title: mood.title,
                        emoji: mood.emoji,
                        icon: mood.icon,
                        isSelected: filterMood == mood
                    ) {
                        filterMood = filterMood == mood ? nil : mood
                    }
                }
            }
        }
        .contentMargins(.horizontal, 24)
        .scrollIndicators(.hidden)
    }

    private func filterChip(title: String, emoji: String?, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let emoji, EmojiSupport.isAvailable {
                    Text(emoji).font(.system(size: 12))
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(title)
                    .font(.footnote.weight(isSelected ? .bold : .medium))
            }
            .foregroundStyle(isSelected ? .white : Theme.tabTrending)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(
                isSelected ? Theme.tabTrending : Theme.tabTrending.opacity(0.10),
                in: .capsule
            )
        }
        .buttonStyle(PressableCardStyle())
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && requests.isEmpty {
            VStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Theme.card)
                        .frame(height: 108)
                        .shimmer()
                }
            }
            .padding(.horizontal, 24)
        } else if let errorMessage, requests.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 34))
                    .foregroundStyle(Theme.tabTrending)
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
            .padding(.vertical, 40)
            .padding(.horizontal, 24)
        } else if requests.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 36))
                    .foregroundStyle(Theme.tabTrending.opacity(0.6))
                Text(L("advice.empty.title"))
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text(filterMood == nil ? L("advice.empty.msg") : L("advice.empty.mood"))
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .padding(.horizontal, 24)
        } else {
            LazyVStack(spacing: 12) {
                ForEach(requests) { request in
                    NavigationLink(value: request) {
                        AdviceRequestCard(request: request) {
                            hideAndRemove(request)
                        } onReport: {
                            Task {
                                await community.report(targetType: "request", targetId: request.id)
                            }
                            hideAndRemove(request)
                        }
                    }
                    .buttonStyle(PressableCardStyle())
                }
            }
            .padding(.horizontal, 24)
            .animation(.spring(duration: 0.3), value: requests)
        }
    }

    // MARK: - Actions

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            requests = try await community.loadRequests(mood: filterMood)
        } catch {
            errorMessage = error.localizedDescription
        }
        if let fresh = try? await community.loadStats() {
            withAnimation(.spring(duration: 0.35)) {
                stats = fresh
            }
        }
    }

    private func hideAndRemove(_ request: AdviceRequest) {
        community.hide(id: request.id)
        withAnimation(.spring(duration: 0.3)) {
            requests.removeAll { $0.id == request.id }
        }
    }
}

/// Card for a single advice request on the board.
struct AdviceRequestCard: View {
    let request: AdviceRequest
    var onHide: (() -> Void)? = nil
    var onReport: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                nicknameBadge

                VStack(alignment: .leading, spacing: 1) {
                    Text(request.isMine ? L("advice.mine") : request.nickname)
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(request.isMine ? Theme.tabTrending : Theme.ink)
                    Text(relativeTime)
                        .font(.caption2)
                        .foregroundStyle(Theme.inkSoft)
                }

                Spacer()

                if let mood = request.moodValue {
                    moodChip(mood)
                }

                if !request.isMine, onHide != nil || onReport != nil {
                    Menu {
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
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.inkSoft)
                            .frame(width: 28, height: 28)
                            .contentShape(.rect)
                    }
                }
            }

            Text(request.text)
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 5) {
                Image(systemName: "bubble.left.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.tabTrending)
                Text(replyCountLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.inkSoft)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft.opacity(0.5))
            }
        }
        .padding(14)
        .background(Theme.card, in: .rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    request.isMine ? Theme.tabTrending.opacity(0.35) : Theme.ink.opacity(0.06),
                    lineWidth: 1
                )
        )
    }

    private var nicknameBadge: some View {
        Text(String(request.nickname.prefix(1)))
            .font(.subheadline.weight(.heavy))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(
                (request.moodValue?.tint ?? Theme.tabTrending).gradient,
                in: .circle
            )
    }

    private func moodChip(_ mood: Mood) -> some View {
        HStack(spacing: 3) {
            if EmojiSupport.isAvailable {
                Text(mood.emoji).font(.system(size: 11))
            } else {
                Image(systemName: mood.icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(mood.tint)
            }
            Text(mood.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(mood.tint)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(mood.tint.opacity(0.14), in: .capsule)
    }

    private var replyCountLabel: String {
        switch request.replyCount {
        case 0: return L("advice.replies.zero")
        case 1: return L("advice.replies.one")
        default: return LF("advice.replies.many", request.replyCount)
        }
    }

    private var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = LocalizationManager.shared.locale
        formatter.unitsStyle = .short
        return formatter.localizedString(for: request.date, relativeTo: Date())
    }
}
