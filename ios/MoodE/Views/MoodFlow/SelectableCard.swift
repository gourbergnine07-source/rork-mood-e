//
//  SelectableCard.swift
//  MoodE
//

import SwiftUI

/// Grid card with emoji + icon used in the guided flow steps.
struct SelectableCard: View {
    let emoji: String
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed: Bool = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    Text(emoji)
                        .font(.system(size: 38))
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : Theme.primary)
                        .padding(6)
                        .background(
                            isSelected ? Theme.primary : Theme.primary.opacity(0.12),
                            in: .circle
                        )
                        .offset(x: 18, y: -6)
                }

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 116)
            .background(
                isSelected ? Theme.primary.opacity(0.14) : .white.opacity(0.65),
                in: .rect(cornerRadius: 22)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(
                        isSelected ? Theme.primary : Theme.primary.opacity(0.10),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .scaleEffect(isSelected ? 1.03 : 1.0)
        }
        .buttonStyle(PressableCardStyle())
        .sensoryFeedback(.selection, trigger: isSelected)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isSelected)
    }
}

/// Full-width row card used for the era step.
struct SelectableRow: View {
    let emoji: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(emoji)
                    .font(.system(size: 30))
                    .frame(width: 52, height: 52)
                    .background(
                        isSelected ? Theme.primary.opacity(0.16) : Theme.primary.opacity(0.08),
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
                    .foregroundStyle(isSelected ? Theme.primary : Theme.primary.opacity(0.25))
            }
            .padding(16)
            .background(
                isSelected ? Theme.primary.opacity(0.12) : .white.opacity(0.65),
                in: .rect(cornerRadius: 22)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(
                        isSelected ? Theme.primary : Theme.primary.opacity(0.10),
                        lineWidth: isSelected ? 2 : 1
                    )
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
