//
//  NotificationInboxView.swift
//  MoodE
//

import SwiftUI

/// In-app notification center: every notification Mood-E delivered is saved
/// and listed here, newest first, with unread dots and swipe-to-delete.
struct NotificationInboxView: View {
    private let history = NotificationHistory.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if history.records.isEmpty {
                emptyState
            } else {
                recordList
            }
        }
        .navigationTitle(L("inbox.title"))
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            if !history.records.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("inbox.clear")) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            history.clear()
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.rose)
                }
            }
        }
        .task {
            // Let the unread dots be visible for a moment, then mark read.
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.easeOut(duration: 0.4)) {
                history.markAllRead()
            }
        }
    }

    // MARK: - List

    private var recordList: some View {
        List {
            ForEach(history.records) { record in
                recordRow(record)
                    .listRowBackground(Theme.card)
                    .listRowSeparatorTint(Theme.inkSoft.opacity(0.15))
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            history.delete(record)
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
    }

    private func recordRow(_ record: NotificationRecord) -> some View {
        Button {
            openRoute(record.route)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon(for: record.route))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color(for: record.route))
                    .frame(width: 36, height: 36)
                    .background(color(for: record.route).opacity(0.12), in: .circle)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .top, spacing: 6) {
                        Text(record.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.leading)

                        Spacer(minLength: 0)

                        if !record.isRead {
                            Circle()
                                .fill(Theme.primary)
                                .frame(width: 8, height: 8)
                                .padding(.top, 5)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }

                    Text(record.body)
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.leading)

                    Text(record.date.formatted(.relative(presentation: .named)))
                        .font(.caption2)
                        .foregroundStyle(Theme.inkSoft.opacity(0.7))
                        .padding(.top, 1)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    /// Notification tap routes: evening reminder → mood flow, watchlist → list tab.
    private func openRoute(_ route: String?) {
        guard let route else { return }
        dismiss()
        NotificationCenter.default.post(
            name: NotificationRoute.notificationName,
            object: route
        )
    }

    private func icon(for route: String?) -> String {
        switch route {
        case NotificationRoute.moodFlow: return "face.smiling"
        case NotificationRoute.watchlist: return "bookmark.fill"
        default: return "sparkles"
        }
    }

    private func color(for route: String?) -> Color {
        switch route {
        case NotificationRoute.moodFlow: return Theme.primary
        case NotificationRoute.watchlist: return Theme.amber
        default: return Theme.rose
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "bell.slash")
                .font(.system(size: 40))
                .foregroundStyle(Theme.primary.opacity(0.4))
            Text(L("inbox.empty.title"))
                .font(.headline)
                .foregroundStyle(Theme.ink)
            Text(L("inbox.empty.msg"))
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
    }
}

#Preview {
    NavigationStack {
        NotificationInboxView()
    }
}
