//
//  PlaceholderCard.swift
//  MoodE
//

import SwiftUI

/// Reusable "coming soon" card used by placeholder tabs.
struct PlaceholderCard: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Theme.primary.opacity(0.12))
                    .frame(width: 96, height: 96)
                Circle()
                    .fill(Theme.primary.opacity(0.10))
                    .frame(width: 72, height: 72)
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(Theme.primary)
            }

            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            Label(L("common.comingSoon"), systemImage: "sparkles")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Theme.primary.opacity(0.12), in: .capsule)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(Theme.card, in: .rect(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Theme.primary.opacity(0.10), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        PlaceholderCard(
            icon: "film",
            title: "Anteprima",
            message: "Contenuto in arrivo."
        )
    }
}
