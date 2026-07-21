//
//  SelectableCard.swift
//  MoodE
//

import SwiftUI

/// Grid card with emoji + icon used in the guided flow steps.
/// When `animatesEmoji` is true, the card enters with a staggered pop
/// and the emoji gently floats in a continuous loop.
struct SelectableCard: View {
    let emoji: String
    let icon: String
    let title: String
    let isSelected: Bool
    var tint: Color = Theme.primary
    var animatesEmoji: Bool = false
    var animationIndex: Int = 0
    /// Compact layout for the 12-mood Home grid, so every card fits on screen.
    var isCompact: Bool = false
    let action: () -> Void

    @State private var hasAppeared: Bool = false
    @State private var isFloating: Bool = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: isCompact ? 5 : 10) {
                ZStack(alignment: .topTrailing) {
                    glyph
                        .scaleEffect(isFloating ? 1.08 : 1.0)
                        .offset(y: isFloating ? -3 : 2)
                    if EmojiSupport.isAvailable {
                        Image(systemName: icon)
                            .font(.system(size: isCompact ? 10 : 12, weight: .semibold))
                            .foregroundStyle(isSelected ? .white : tint)
                            .padding(isCompact ? 5 : 6)
                            .background(
                                isSelected ? tint : Theme.cardStrong,
                                in: .circle
                            )
                            .offset(x: isCompact ? 15 : 18, y: isCompact ? -5 : -6)
                    }
                }

                Text(title)
                    .font(isCompact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(isCompact ? 1 : 2)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .frame(height: isCompact ? 84 : 116)
            .background(
                LinearGradient(
                    colors: isSelected
                        ? [tint.opacity(0.50), tint.opacity(0.28)]
                        : [tint.opacity(0.26), tint.opacity(0.12)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: .rect(cornerRadius: 22)
            )
            .background(Theme.cardStrong, in: .rect(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(
                        isSelected ? tint : tint.opacity(0.35),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(
                color: tint.opacity(isSelected ? 0.35 : 0.15),
                radius: isSelected ? 10 : 5,
                x: 0,
                y: 4
            )
            .scaleEffect(isSelected ? 1.03 : 1.0)
        }
        .buttonStyle(PressableCardStyle())
        .sensoryFeedback(.selection, trigger: isSelected)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isSelected)
        .opacity(hasAppeared ? 1 : 0)
        .scaleEffect(hasAppeared ? 1 : 0.6)
        .onAppear { startAnimations() }
    }

    /// Emoji when the emoji font exists, otherwise the tinted SF Symbol
    /// (preview simulators without Apple Color Emoji would show "?").
    @ViewBuilder
    private var glyph: some View {
        if EmojiSupport.isAvailable {
            Text(emoji)
                .font(.system(size: isCompact ? 28 : 38))
        } else {
            Image(systemName: icon)
                .font(.system(size: isCompact ? 22 : 30, weight: .semibold))
                .foregroundStyle(tint)
                .frame(height: isCompact ? 32 : 44)
        }
    }

    private func startAnimations() {
        guard animatesEmoji else {
            hasAppeared = true
            return
        }

        withAnimation(
            .spring(response: 0.5, dampingFraction: 0.65)
            .delay(Double(animationIndex) * 0.06)
        ) {
            hasAppeared = true
        }

        withAnimation(
            .easeInOut(duration: 1.6)
            .repeatForever(autoreverses: true)
            .delay(Double(animationIndex) * 0.18)
        ) {
            isFloating = true
        }
    }
}

/// Full-width row card used for the era step.
struct SelectableRow: View {
    let emoji: String
    var icon: String = "film"
    let title: String
    let subtitle: String
    let isSelected: Bool
    var tint: Color = Theme.primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Group {
                    if EmojiSupport.isAvailable {
                        Text(emoji)
                            .font(.system(size: 30))
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(tint)
                    }
                }
                .frame(width: 52, height: 52)
                .background(
                    isSelected ? tint.opacity(0.30) : tint.opacity(0.16),
                    in: .rect(cornerRadius: 16)
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? tint : tint.opacity(0.35))
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: isSelected
                        ? [tint.opacity(0.40), tint.opacity(0.20)]
                        : [tint.opacity(0.20), tint.opacity(0.08)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: .rect(cornerRadius: 22)
            )
            .background(Theme.cardStrong, in: .rect(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(
                        isSelected ? tint : tint.opacity(0.30),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(
                color: tint.opacity(isSelected ? 0.30 : 0.12),
                radius: isSelected ? 9 : 4,
                x: 0,
                y: 3
            )
        }
        .buttonStyle(PressableCardStyle())
        .sensoryFeedback(.selection, trigger: isSelected)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isSelected)
    }
}

/// Subtle press-down effect for selectable cards.
struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
