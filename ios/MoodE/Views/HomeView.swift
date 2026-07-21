//
//  HomeView.swift
//  MoodE
//

import SwiftUI

/// Home tab: hosts the guided emotion → goal → era flow,
/// plus quick access to the emotional diary and the current streak.
struct HomeView: View {
    @Environment(MoodDiary.self) private var diary
    private let history = NotificationHistory.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                MoodFlowView()
            }
            .navigationTitle("Mood-E")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink(value: HomeRoute.diary) {
                        HStack(spacing: 4) {
                            Text("🔥")
                                .font(.system(size: 14))
                                .opacity(diary.streak > 0 ? 1 : 0.4)
                            Text("\(diary.streak)")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(diary.streak > 0 ? Theme.primary : Theme.inkSoft)
                                .contentTransition(.numericText())
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            (diary.streak > 0 ? Theme.primary : Theme.inkSoft).opacity(0.12),
                            in: .capsule
                        )
                    }
                    .accessibilityLabel(
                        diary.streak > 0
                            ? LF("diary.streak.days", diary.streak)
                            : L("diary.streak.start.title")
                    )
                }

                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: HomeRoute.notifications) {
                        Image(systemName: history.unreadCount > 0 ? "bell.badge" : "bell")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(history.unreadCount > 0 ? Theme.rose : Theme.primary, Theme.primary)
                            .symbolRenderingMode(.palette)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .accessibilityLabel(L("inbox.title"))
                }

                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: HomeRoute.diary) {
                        Image(systemName: "calendar")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.primary)
                    }
                    .accessibilityLabel(L("diary.title"))
                }
            }
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .diary: DiaryView()
                case .diaryDay(let day): DiaryView(initialDay: day)
                case .notifications: NotificationInboxView()
                }
            }
            .navigationDestination(for: DiaryRoute.self) { route in
                switch route {
                case .badges: BadgesView()
                case .memories: MemoriesView()
                case .stats: MyStatsView()
                case .friends: FriendsView()
                }
            }
        }
        .tint(Theme.primary)
    }
}

/// Navigation destinations reachable from the Home tab root.
enum HomeRoute: Hashable {
    case diary
    /// Diary opened straight on a specific day ("Un anno fa oggi").
    case diaryDay(Date)
    case notifications
}

#Preview {
    HomeView()
        .environment(MoodDiary())
        .environment(MovieLibrary())
}
