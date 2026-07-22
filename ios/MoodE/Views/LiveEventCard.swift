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
            HStack(spacing: 10) {
                Group {
                    if EmojiSupport.isAvailable {
                        Text(event.emoji)
                            .font(.system(size: 14))
                    } else {
                        Image(systemName: event.icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 26, height: 26)
                .background(.white.opacity(0.20), in: .circle)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(event.title)
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(countdownText)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.white.opacity(0.24), in: .capsule)
                            .layoutPriority(1)
                    }
                    Text(event.detail)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: event.gradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: .rect(cornerRadius: 13)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .stroke(.white.opacity(0.16), lineWidth: 1)
            )
            .shadow(color: (event.gradient.first ?? .black).opacity(0.15), radius: 4, y: 2)
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
