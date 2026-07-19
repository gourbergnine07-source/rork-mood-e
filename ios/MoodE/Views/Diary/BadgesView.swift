//
//  BadgesView.swift
//  MoodE
//

import SwiftUI

/// Personal achievements grid: gentle gamification, no leaderboards.
struct BadgesView: View {
    @Environment(MoodDiary.self) private var diary
    @Environment(MovieLibrary.self) private var library

    private var stats: DiaryStats {
        diary.stats(watchedTotal: library.lifetimeWatchedCount)
    }

    var body: some View {
        let stats = stats
        let unlocked = Badge.allCases.filter { $0.isUnlocked(stats) }.count

        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LF("badges.unlockedCount", unlocked, Badge.allCases.count))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Theme.ink)
                        Text(L("badges.subtitle"))
                            .font(.footnote)
                            .foregroundStyle(Theme.inkSoft)
                    }

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(Badge.allCases) { badge in
                            BadgeCard(
                                badge: badge,
                                isUnlocked: badge.isUnlocked(stats),
                                progress: badge.progress(stats)
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(L("badges.title"))
        .toolbarTitleDisplayMode(.inline)
    }
}

/// Single badge tile with emoji, name and a soft progress bar when locked.
private struct BadgeCard: View {
    let badge: Badge
    let isUnlocked: Bool
    let progress: Double

    var body: some View {
        VStack(spacing: 8) {
            Text(badge.emoji)
                .font(.system(size: 34))
                .grayscale(isUnlocked ? 0 : 1)
                .opacity(isUnlocked ? 1 : 0.5)

            Text(badge.title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)

            Text(badge.detail)
                .font(.caption2)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(maxWidth: .infinity)

            if isUnlocked {
                Label(L("badges.unlocked"), systemImage: "checkmark.seal.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.seenGreen)
            } else {
                ProgressView(value: progress)
                    .tint(Theme.amber)
                    .scaleEffect(y: 0.7)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .top)
        .background(Theme.card, in: .rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    isUnlocked ? Theme.amber.opacity(0.4) : Theme.primary.opacity(0.08),
                    lineWidth: 1
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(badge.title), \(isUnlocked ? L("badges.unlocked") : L("badges.locked"))")
    }
}

#Preview {
    NavigationStack {
        BadgesView()
    }
    .environment(MoodDiary())
    .environment(MovieLibrary())
}
