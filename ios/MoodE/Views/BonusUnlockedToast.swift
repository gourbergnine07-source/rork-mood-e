//
//  BonusUnlockedToast.swift
//  MoodE
//

import SwiftUI

/// Floating confirmation shown when a rewarded video has been watched in
/// full: celebrates the unlocked extra recommendations for a few seconds.
struct BonusUnlockedToast: View {
    var body: some View {
        HStack(spacing: 12) {
            sparkle

            VStack(alignment: .leading, spacing: 2) {
                Text(L("results.bonus.unlocked.title"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.ink)
                Text(L("results.bonus.unlocked.msg"))
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(Theme.card, in: .rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Theme.amber.opacity(0.45), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
    }

    @ViewBuilder
    private var sparkle: some View {
        if EmojiSupport.isAvailable {
            Text("🎉")
                .font(.system(size: 24))
        } else {
            Image(systemName: "gift.fill")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Theme.amber)
        }
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        BonusUnlockedToast()
    }
}
