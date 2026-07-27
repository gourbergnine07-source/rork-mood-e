//
//  StatusStripView.swift
//  MoodE
//

import SwiftUI

/// Horizontal story-style strip of anonymous "Stato Mood" avatars,
/// shown at the top of the community board. The first bubble is the
/// user's own (tap to view or publish); the others are FRIENDS ONLY —
/// people linked via a "Serata in Duo" or "Sfida un amico" code — with
/// an active status in the last 24 hours (WhatsApp-style visibility,
/// enforced server-side). A colored ring marks unseen statuses; a muted
/// ring marks already-seen ones.
struct StatusStripView: View {
    @State private var groups: [StatusGroup] = []
    @State private var isLoading: Bool = false
    @State private var hasLoaded: Bool = false
    @State private var showComposer: Bool = false
    @State private var showFriends: Bool = false
    @State private var viewerTarget: StatusViewerTarget?
    @State private var moodFilter: Mood?

    private var service: StatusService { StatusService.shared }

    private var myGroup: StatusGroup? { groups.first { $0.isMine } }

    /// Moods actually present in the current feed, in canonical order.
    private var availableMoods: [Mood] {
        let present = Set(groups.flatMap { $0.statuses.compactMap(\.mood) })
        return Mood.allCases.filter { present.contains($0.rawValue) }
    }

    /// Groups restricted to the selected mood (statuses without that tag drop out).
    private var filteredGroups: [StatusGroup] {
        guard let moodFilter else { return groups }
        return groups.compactMap { group in
            let matching = group.statuses.filter { $0.mood == moodFilter.rawValue }
            guard !matching.isEmpty else { return nil }
            return StatusGroup(
                authorId: group.authorId,
                nickname: group.nickname,
                isMine: group.isMine,
                statuses: matching
            )
        }
    }

    private var otherGroups: [StatusGroup] { filteredGroups.filter { !$0.isMine } }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(L("status.strip.title"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.ink)

                Spacer(minLength: 8)

                Button {
                    showFriends = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 10, weight: .semibold))
                        Text(L("status.friends.title"))
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(Theme.tabTrending)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(Theme.tabTrending.opacity(0.12), in: .capsule)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)

            if !availableMoods.isEmpty {
                moodFilterRow
            }

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    myBubble

                    if isLoading && groups.isEmpty {
                        ForEach(0..<4, id: \.self) { _ in
                            VStack(spacing: 5) {
                                Circle()
                                    .fill(Theme.card)
                                    .frame(width: 62, height: 62)
                                    .shimmer()
                                Capsule()
                                    .fill(Theme.card)
                                    .frame(width: 48, height: 8)
                            }
                        }
                    } else {
                        ForEach(otherGroups) { group in
                            bubble(for: group)
                        }
                        if moodFilter != nil && otherGroups.isEmpty {
                            filterEmptyHint
                        } else if moodFilter == nil && otherGroups.isEmpty {
                            noFriendsHint
                        }
                    }
                }
            }
            .contentMargins(.horizontal, 24)
            .scrollIndicators(.hidden)
        }
        .task {
            guard !hasLoaded else { return }
            hasLoaded = true
            await load()
        }
        .sheet(isPresented: $showComposer) {
            StatusComposerView {
                Task { await load() }
            }
        }
        .sheet(isPresented: $showFriends) {
            CommunityFriendsView()
        }
        .fullScreenCover(item: $viewerTarget) { target in
            StatusViewerView(groups: target.groups, startGroupIndex: target.startIndex) {
                Task { await load() }
            }
        }
    }

    // MARK: - Mood filters

    /// Icon chips filtering the strip by the mood tagged on each status.
    private var moodFilterRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                filterChip(
                    title: L("status.filter.all"),
                    icon: "line.3.horizontal.decrease",
                    tint: Theme.tabTrending,
                    isSelected: moodFilter == nil
                ) {
                    moodFilter = nil
                }

                ForEach(availableMoods) { mood in
                    filterChip(
                        title: mood.title,
                        icon: mood.icon,
                        tint: mood.tint,
                        isSelected: moodFilter == mood
                    ) {
                        moodFilter = moodFilter == mood ? nil : mood
                    }
                }
            }
        }
        .contentMargins(.horizontal, 24)
        .scrollIndicators(.hidden)
        .sensoryFeedback(.selection, trigger: moodFilter)
    }

    private func filterChip(
        title: String,
        icon: String,
        tint: Color,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            withAnimation(.spring(duration: 0.25)) {
                action()
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(isSelected ? .white : tint)
            .padding(.horizontal, 11)
            .frame(height: 30)
            .background(isSelected ? tint : tint.opacity(0.14), in: .capsule)
            .overlay(
                Capsule().stroke(tint.opacity(isSelected ? 0 : 0.35), lineWidth: 1)
            )
        }
        .buttonStyle(PressableCardStyle())
    }

    /// Shown when the selected mood matches no one else's status.
    private var filterEmptyHint: some View {
        Text(L("status.filter.empty"))
            .font(.caption)
            .foregroundStyle(Theme.inkSoft)
            .frame(height: 62)
    }

    /// Friends-only visibility: with no linked friends (or none with an
    /// active status), invite the user to the code-based features.
    private var noFriendsHint: some View {
        Text(L("status.strip.noFriends"))
            .font(.caption)
            .foregroundStyle(Theme.inkSoft)
            .lineSpacing(2)
            .frame(maxWidth: 240, minHeight: 62, alignment: .leading)
            .multilineTextAlignment(.leading)
    }

    // MARK: - Bubbles

    private var myBubble: some View {
        Button {
            if let myGroup, let index = groups.firstIndex(of: myGroup) {
                viewerTarget = StatusViewerTarget(groups: groups, startIndex: index)
            } else {
                showComposer = true
            }
        } label: {
            VStack(spacing: 5) {
                ZStack(alignment: .bottomTrailing) {
                    StatusAvatarView(
                        nickname: CommunityService.shared.nickname,
                        size: 62,
                        ring: myGroup != nil ? .unseen : .none
                    )
                    plusBadge
                }
                Text(myGroup != nil ? L("advice.mine") : L("status.strip.you"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
            }
            .frame(width: 68)
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityLabel(L("status.strip.publish"))
        .sensoryFeedback(.impact(weight: .light), trigger: showComposer)
    }

    private var plusBadge: some View {
        Button {
            showComposer = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Theme.tabTrending, in: .circle)
                .overlay(Circle().stroke(Theme.background, lineWidth: 2))
        }
        .offset(x: 2, y: 2)
    }

    private func bubble(for group: StatusGroup) -> some View {
        Button {
            let visible = filteredGroups
            if let index = visible.firstIndex(of: group) {
                viewerTarget = StatusViewerTarget(groups: visible, startIndex: index)
            }
        } label: {
            VStack(spacing: 5) {
                StatusAvatarView(
                    nickname: group.nickname,
                    size: 62,
                    ring: group.hasUnseen ? .unseen : .seen
                )
                Text(group.nickname)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(group.hasUnseen ? Theme.ink : Theme.inkSoft)
                    .lineLimit(1)
            }
            .frame(width: 68)
        }
        .buttonStyle(PressableCardStyle())
    }

    // MARK: - Data

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        if let fresh = try? await service.loadFeed() {
            withAnimation(.spring(duration: 0.3)) {
                groups = fresh
                // Drop the filter if that mood disappeared from the feed.
                if let moodFilter, !availableMoods.contains(moodFilter) {
                    self.moodFilter = nil
                }
            }
        }
    }
}

/// Identifiable payload for the full-screen story viewer.
struct StatusViewerTarget: Identifiable {
    let id = UUID()
    let groups: [StatusGroup]
    let startIndex: Int
}

/// Ring state around a status avatar.
enum StatusAvatarRing {
    case unseen
    case seen
    case none
}

/// Auto-generated circular avatar for an anonymous nickname:
/// initials on a deterministic color (no real profile pictures exist).
struct StatusAvatarView: View {
    let nickname: String
    let size: CGFloat
    var ring: StatusAvatarRing = .none

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.34, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(avatarColor.gradient, in: .circle)
            .overlay {
                switch ring {
                case .unseen:
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [Theme.tabTrending, Theme.rose, Theme.amber, Theme.tabTrending],
                                center: .center
                            ),
                            lineWidth: 2.5
                        )
                        .padding(-4)
                case .seen:
                    Circle()
                        .stroke(Theme.inkSoft.opacity(0.35), lineWidth: 2)
                        .padding(-4)
                case .none:
                    EmptyView()
                }
            }
    }

    private var initials: String {
        String(nickname.prefix(2)).uppercased()
    }

    /// Deterministic hue derived from the nickname, stable across launches.
    private var avatarColor: Color {
        var hash: UInt64 = 5381
        for byte in nickname.utf8 {
            hash = hash &* 33 &+ UInt64(byte)
        }
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.55, brightness: 0.72)
    }
}
