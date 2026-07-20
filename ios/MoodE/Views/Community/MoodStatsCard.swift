//
//  MoodStatsCard.swift
//  MoodE
//

import SwiftUI

/// "Moods of the week" card shown at the top of the Consigli board:
/// anonymous aggregate of the most requested moods over the last 7 days,
/// with animated bars and all-time community totals.
struct MoodStatsCard: View {
    let stats: AdviceStats

    @State private var animateBars = false

    /// Top three moods of the week (already sorted by the server).
    private var topMoods: [AdviceMoodCount] {
        Array(stats.moods.prefix(3))
    }

    private var maxCount: Int {
        max(topMoods.first?.count ?? 1, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.tabTrending)
                Text(L("advice.stats.title"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.ink)
                Spacer()
            }

            VStack(spacing: 10) {
                ForEach(Array(topMoods.enumerated()), id: \.element.id) { index, item in
                    moodBar(item, rank: index)
                }
            }

            HStack(spacing: 12) {
                totalChip(
                    icon: "bubble.left.fill",
                    value: stats.totalRequests,
                    label: L("advice.stats.requests")
                )
                totalChip(
                    icon: "popcorn.fill",
                    value: stats.totalReplies,
                    label: L("advice.stats.replies")
                )
                Spacer()
            }
        }
        .padding(14)
        .background(Theme.card, in: .rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Theme.ink.opacity(0.06), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.1)) {
                animateBars = true
            }
        }
    }

    private func moodBar(_ item: AdviceMoodCount, rank: Int) -> some View {
        let mood = item.moodValue
        let tint = mood?.tint ?? Theme.tabTrending
        let fraction = CGFloat(item.count) / CGFloat(maxCount)

        return HStack(spacing: 10) {
            Group {
                if let mood, EmojiSupport.isAvailable {
                    Text(mood.emoji)
                        .font(.system(size: 15))
                } else if let mood {
                    Image(systemName: mood.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(tint)
                }
            }
            .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(mood?.title ?? item.mood)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.ink)

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(tint.opacity(0.12))
                        Capsule()
                            .fill(tint.gradient)
                            .frame(width: animateBars ? max(proxy.size.width * fraction, 10) : 10)
                    }
                }
                .frame(height: 7)
                .animation(
                    .spring(response: 0.7, dampingFraction: 0.8).delay(Double(rank) * 0.12),
                    value: animateBars
                )
            }

            Text("\(item.count)")
                .font(.footnote.weight(.bold))
                .foregroundStyle(tint)
                .monospacedDigit()
                .frame(minWidth: 20, alignment: .trailing)
        }
    }

    private func totalChip(icon: String, value: Int, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.tabTrending)
            Text("\(value)")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.ink)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.inkSoft)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Theme.tabTrending.opacity(0.08), in: .capsule)
    }
}
