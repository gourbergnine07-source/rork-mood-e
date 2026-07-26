//
//  StatusStripView.swift
//  MoodE
//

import SwiftUI

/// Horizontal story-style strip of anonymous "Stato Mood" avatars,
/// shown at the top of the community board. The first bubble is the
/// user's own (tap to view or publish), the others are authors with an
/// active status in the last 24 hours. A colored ring marks unseen
/// statuses; a muted ring marks already-seen ones.
struct StatusStripView: View {
    @State private var groups: [StatusGroup] = []
    @State private var isLoading: Bool = false
    @State private var hasLoaded: Bool = false
    @State private var showComposer: Bool = false
    @State private var viewerTarget: StatusViewerTarget?

    private var service: StatusService { StatusService.shared }

    private var myGroup: StatusGroup? { groups.first { $0.isMine } }
    private var otherGroups: [StatusGroup] { groups.filter { !$0.isMine } }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("status.strip.title"))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 24)

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
        .fullScreenCover(item: $viewerTarget) { target in
            StatusViewerView(groups: target.groups, startGroupIndex: target.startIndex) {
                Task { await load() }
            }
        }
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
            if let index = groups.firstIndex(of: group) {
                viewerTarget = StatusViewerTarget(groups: groups, startIndex: index)
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
