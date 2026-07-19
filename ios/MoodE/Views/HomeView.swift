//
//  HomeView.swift
//  MoodE
//

import SwiftUI

/// Home tab: hosts the guided emotion → goal → era flow,
/// plus quick access to the emotional diary and the current streak.
struct HomeView: View {
    @Environment(MoodDiary.self) private var diary

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                MoodFlowView()
            }
            .navigationTitle("Mood-E")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                if diary.streak > 0 {
                    ToolbarItem(placement: .topBarLeading) {
                        NavigationLink(value: HomeRoute.diary) {
                            HStack(spacing: 4) {
                                Text("🔥")
                                    .font(.system(size: 14))
                                Text("\(diary.streak)")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Theme.primary)
                                    .contentTransition(.numericText())
                                    .monospacedDigit()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Theme.primary.opacity(0.12), in: .capsule)
                        }
                        .accessibilityLabel(LF("diary.streak.days", diary.streak))
                    }
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
                }
            }
            .navigationDestination(for: DiaryRoute.self) { route in
                switch route {
                case .badges: BadgesView()
                }
            }
        }
        .tint(Theme.primary)
    }
}

/// Navigation destinations reachable from the Home tab root.
enum HomeRoute: Hashable {
    case diary
}

#Preview {
    HomeView()
        .environment(MoodDiary())
        .environment(MovieLibrary())
}
