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
    private var premium: PremiumStore { .shared }

    @State private var showPosterScan: Bool = false
    @State private var showScanPaywall: Bool = false

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
                            if EmojiSupport.isAvailable {
                                Text("🔥")
                                    .font(.system(size: 14))
                                    .opacity(diary.streak > 0 ? 1 : 0.4)
                            } else {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(diary.streak > 0 ? Theme.primary : Theme.inkSoft)
                                    .opacity(diary.streak > 0 ? 1 : 0.4)
                            }
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
                    Button {
                        if premium.isPremium {
                            showPosterScan = true
                        } else {
                            showScanPaywall = true
                        }
                    } label: {
                        ZStack(alignment: .bottomTrailing) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.primary)

                            if !premium.isPremium {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 6, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 11, height: 11)
                                    .background(Theme.ink.opacity(0.85), in: .circle)
                                    .offset(x: 4, y: 4)
                            }
                        }
                    }
                    .accessibilityLabel(L("scan.title"))
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
            .sheet(isPresented: $showPosterScan) {
                PosterScanView()
            }
            .sheet(isPresented: $showScanPaywall) {
                PaywallView()
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
