//
//  UnlockToastView.swift
//  MoodE
//

import SwiftUI

/// Temporary in-app banner celebrating a freshly unlocked icon or theme.
/// Slides in from the top with a sparkle animation, then auto-dismisses.
struct UnlockToastView: View {
    let reward: UnlockedReward
    let onDismiss: () -> Void

    @State private var sparklePhase: Bool = false
    @State private var appeared: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.amber.opacity(0.18))
                    .frame(width: 44, height: 44)
                Text(reward.emoji)
                    .font(.system(size: 24))
                    .scaleEffect(sparklePhase ? 1.15 : 0.9)
                    .rotationEffect(.degrees(sparklePhase ? 8 : -8))
            }

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.amber)
                    Text(L("perso.toast.title"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.amber)
                        .textCase(.uppercase)
                        .kerning(0.5)
                }
                Text(reward.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(width: 28, height: 28)
                    .background(Theme.inkSoft.opacity(0.12), in: .circle)
            }
            .accessibilityLabel(L("common.close"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.cardStrong, in: .rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Theme.amber.opacity(0.5), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.22), radius: 14, y: 6)
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .scaleEffect(appeared ? 1 : 0.85)
        .opacity(appeared ? 1 : 0)
        .sensoryFeedback(.success, trigger: appeared)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                sparklePhase = true
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(3.5))
            onDismiss()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(L("perso.toast.title")): \(reward.title)")
    }
}
