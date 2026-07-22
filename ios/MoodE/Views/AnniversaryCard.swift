//
//  AnniversaryCard.swift
//  MoodE
//

import SwiftUI

/// "Un anno fa oggi": small dismissible memory card shown on the Home
/// step when a check-in exists about 12 months ago. Tapping it opens
/// the diary straight on that day.
struct AnniversaryCard: View {
    @Environment(MoodDiary.self) private var diary
    @Environment(MovieLibrary.self) private var library

    @State private var dismissed: Bool = false

    private static let dismissedDayKey = "anniversary.dismissedDay"

    var body: some View {
        if !dismissed, !isDismissedToday, let checkIn = diary.anniversaryCheckIn(), let mood = checkIn.mood {
            card(checkIn: checkIn, mood: mood)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private func card(checkIn: MoodCheckIn, mood: Mood) -> some View {
        HStack(spacing: 10) {
            NavigationLink(value: HomeRoute.diaryDay(checkIn.date)) {
                HStack(spacing: 10) {
                    Text(mood.emoji)
                        .font(.system(size: 16))
                        .frame(width: 28, height: 28)
                        .background(mood.tint.opacity(0.15), in: .circle)

                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 5) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 10, weight: .semibold))
                            Text(L("home.anniversary.title"))
                                .font(.caption.weight(.bold))
                        }
                        .foregroundStyle(Theme.amber)

                        Text(message(checkIn: checkIn, mood: mood))
                            .font(.caption2)
                            .foregroundStyle(Theme.ink)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.amber)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            Button {
                UserDefaults.standard.set(todayKey, forKey: Self.dismissedDayKey)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    dismissed = true
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(width: 22, height: 22)
                    .background(Theme.surface.opacity(0.7), in: .circle)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L("common.close"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Theme.amber.opacity(0.10), in: .rect(cornerRadius: 13))
        .overlay(
            RoundedRectangle(cornerRadius: 13)
                .stroke(Theme.amber.opacity(0.30), lineWidth: 1)
        )
    }

    /// "Ti sentivi X" + the movie watched (or proposed) that day, if any.
    private func message(checkIn: MoodCheckIn, mood: Mood) -> String {
        var text = LF("home.anniversary.mood", mood.title.lowercased())
        if let title = movieTitle(around: checkIn) {
            text += " " + LF("home.anniversary.movie", title)
        }
        text += " " + L("home.anniversary.question")
        return text
    }

    private func movieTitle(around checkIn: MoodCheckIn) -> String? {
        let calendar = Calendar.current
        let watched = library.watched.first { entry in
            guard let date = entry.watchedDate else { return false }
            return calendar.isDate(date, inSameDayAs: checkIn.date)
        }
        return watched?.title ?? checkIn.proposed.first?.title
    }

    private var todayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date())
    }

    private var isDismissedToday: Bool {
        UserDefaults.standard.string(forKey: Self.dismissedDayKey) == todayKey
    }
}
