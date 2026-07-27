//
//  CommunityFriendsView.swift
//  MoodE
//
//  "I miei amici": the anonymous people linked via a "Serata in Duo" or
//  "Sfida un amico" code. Only their nickname and the date of the first
//  connection are known — consistent with the community's anonymity.
//  These are the ONLY people who can see (and whose statuses appear in)
//  the friends-only "Stato Mood" strip.
//

import SwiftUI

struct CommunityFriendsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var friends: [StatusFriend] = []
    @State private var isLoading: Bool = true

    private var service: StatusService { StatusService.shared }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if isLoading && friends.isEmpty {
                            loadingRows
                        } else if friends.isEmpty {
                            emptyState
                        } else {
                            friendsList
                        }

                        Text(L("status.friends.note"))
                            .font(.caption2)
                            .foregroundStyle(Theme.inkSoft.opacity(0.8))
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
                .refreshable { await load() }
            }
            .navigationTitle(L("status.friends.title"))
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    .accessibilityLabel(L("common.close"))
                }
            }
            .task { await load() }
        }
        .tint(Theme.tabTrending)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
    }

    // MARK: - States

    private var loadingRows: some View {
        VStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.card)
                    .frame(height: 64)
                    .shimmer()
            }
        }
    }

    /// Gentle invite to use the code-based features to make friends.
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2")
                .font(.system(size: 34))
                .foregroundStyle(Theme.tabTrending.opacity(0.6))
            Text(L("status.friends.empty"))
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .background(Theme.card.opacity(0.6), in: .rect(cornerRadius: 20))
    }

    private var friendsList: some View {
        VStack(spacing: 10) {
            ForEach(friends) { friend in
                HStack(spacing: 12) {
                    StatusAvatarView(nickname: friend.nickname, size: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(friend.nickname)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        Text(LF("status.friends.since", formattedDate(friend.date)))
                            .font(.caption)
                            .foregroundStyle(Theme.inkSoft)
                    }

                    Spacer(minLength: 0)
                }
                .padding(13)
                .background(Theme.card, in: .rect(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Theme.tabTrending.opacity(0.10), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Data

    private func load() async {
        defer { isLoading = false }
        if let fresh = try? await service.loadFriends() {
            withAnimation(.spring(duration: 0.3)) {
                friends = fresh
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(date: .abbreviated, time: .omitted)
                .locale(LocalizationManager.shared.locale)
        )
    }
}

#Preview {
    CommunityFriendsView()
}
