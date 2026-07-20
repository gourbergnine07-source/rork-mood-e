//
//  LiveEventCard.swift
//  MoodE
//

import SwiftUI

/// Home countdown card for the nearest live cinema event within 14 days
/// ("🏆 Notte degli Oscar tra 5 giorni"). Tapping it opens the dedicated
/// movie collection, reusing the featured-collection screen.
struct LiveEventCard: View {
    let event: LiveEvent
    let days: Int

    private var countdownText: String {
        switch days {
        case 0: return L("event.today")
        case 1: return L("event.tomorrow")
        default: return LF("event.inDays", days)
        }
    }

    var body: some View {
        NavigationLink(value: event.collection) {
            HStack(spacing: 12) {
                Group {
                    if EmojiSupport.isAvailable {
                        Text(event.emoji)
                            .font(.system(size: 26))
                    } else {
                        Image(systemName: event.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.20), in: .circle)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(event.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(countdownText)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.white.opacity(0.24), in: .capsule)
                            .layoutPriority(1)
                    }
                    Text(event.detail)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(14)
            .background(
                LinearGradient(
                    colors: event.gradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: .rect(cornerRadius: 18)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(.white.opacity(0.16), lineWidth: 1)
            )
            .shadow(color: (event.gradient.first ?? .black).opacity(0.25), radius: 8, y: 4)
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityLabel("\(event.title), \(countdownText). \(event.detail)")
    }
}

#Preview {
    NavigationStack {
        ZStack {
            Theme.background.ignoresSafeArea()
            LiveEventCard(event: LiveEventCalendar.all[0], days: 5)
                .padding(24)
        }
    }
}
