//
//  DiaryView.swift
//  MoodE
//

import SwiftUI

/// "Il mio diario": monthly mood calendar, weekly recap, streak and day detail.
struct DiaryView: View {
    @Environment(MoodDiary.self) private var diary
    @Environment(MovieLibrary.self) private var library

    @State private var displayedMonth: Date = Calendar.current.startOfMonth(for: Date())
    @State private var selectedDay: Date = Calendar.current.startOfDay(for: Date())
    @State private var recap: WeeklyRecap?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let recap {
                        WeeklyRecapCard(recap: recap) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                diary.dismissWeeklyRecap()
                                self.recap = nil
                            }
                        }
                    }

                    StreakCard(streak: diary.streak, wasInterrupted: diary.streakWasInterrupted)

                    calendarCard

                    dayDetail

                    NavigationLink(value: DiaryRoute.badges) {
                        badgesRow
                    }
                    .buttonStyle(PressableCardStyle())
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(L("diary.title"))
        .toolbarTitleDisplayMode(.inline)
        .task {
            recap = diary.pendingWeeklyRecap(watched: library.watched)
        }
    }

    // MARK: - Calendar

    private var calendarCard: some View {
        VStack(spacing: 12) {
            monthHeader
            weekdayHeader
            monthGrid
        }
        .padding(16)
        .background(Theme.card, in: .rect(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.primary.opacity(0.10), lineWidth: 1)
        )
    }

    private var monthHeader: some View {
        HStack {
            Button {
                shiftMonth(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.primary)
                    .frame(width: 32, height: 32)
                    .background(Theme.primary.opacity(0.10), in: .circle)
            }

            Spacer()

            Text(monthTitle)
                .font(.headline)
                .foregroundStyle(Theme.ink)

            Spacer()

            Button {
                shiftMonth(1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(canGoForward ? Theme.primary : Theme.inkSoft.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .background(Theme.primary.opacity(canGoForward ? 0.10 : 0.04), in: .circle)
            }
            .disabled(!canGoForward)
        }
        .sensoryFeedback(.selection, trigger: displayedMonth)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(orderedWeekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthGrid: some View {
        let days = monthDays
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                if let day {
                    DiaryDayCell(
                        day: day,
                        emoji: diary.moodEmoji(on: day),
                        isSelected: Calendar.current.isDate(day, inSameDayAs: selectedDay),
                        isToday: Calendar.current.isDateInToday(day)
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedDay = day
                        }
                    }
                } else {
                    Color.clear.frame(height: 44)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selectedDay)
    }

    // MARK: - Day detail

    private var dayDetail: some View {
        let checkIns = diary.checkIns(on: selectedDay)
        let watchedThatDay = library.watched.filter {
            guard let date = $0.watchedDate else { return false }
            return Calendar.current.isDate(date, inSameDayAs: selectedDay)
        }

        return VStack(alignment: .leading, spacing: 12) {
            Text(dayDetailTitle)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.ink)

            if checkIns.isEmpty && watchedThatDay.isEmpty {
                Text(L("diary.day.empty"))
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            ForEach(checkIns) { checkIn in
                DiaryCheckInRow(checkIn: checkIn)
            }

            if !watchedThatDay.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label(L("diary.day.watched"), systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.seenGreen)
                    ForEach(watchedThatDay) { entry in
                        Text("• \(entry.title)")
                            .font(.footnote)
                            .foregroundStyle(Theme.ink)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: .rect(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.primary.opacity(0.10), lineWidth: 1)
        )
    }

    // MARK: - Badges row

    private var badgesRow: some View {
        HStack(spacing: 12) {
            Text("🏅")
                .font(.system(size: 26))
            VStack(alignment: .leading, spacing: 2) {
                Text(L("diary.badges"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(badgesSubtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
        }
        .padding(16)
        .background(Theme.card, in: .rect(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.amber.opacity(0.25), lineWidth: 1)
        )
    }

    private var badgesSubtitle: String {
        let stats = diary.stats(watchedTotal: library.lifetimeWatchedCount)
        let unlocked = Badge.allCases.filter { $0.isUnlocked(stats) }.count
        return LF("diary.badges.count", unlocked, Badge.allCases.count)
    }

    // MARK: - Helpers

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = LocalizationManager.shared.locale
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: displayedMonth).capitalized
    }

    private var dayDetailTitle: String {
        if Calendar.current.isDateInToday(selectedDay) { return L("diary.today") }
        let formatter = DateFormatter()
        formatter.locale = LocalizationManager.shared.locale
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: selectedDay).capitalized
    }

    private var canGoForward: Bool {
        displayedMonth < Calendar.current.startOfMonth(for: Date())
    }

    private func shiftMonth(_ delta: Int) {
        guard let next = Calendar.current.date(byAdding: .month, value: delta, to: displayedMonth) else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            displayedMonth = next
        }
    }

    /// Weekday symbols reordered to the locale's first weekday.
    private var orderedWeekdaySymbols: [String] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = LocalizationManager.shared.locale
        let symbols = formatter.veryShortWeekdaySymbols ?? ["S", "M", "T", "W", "T", "F", "S"]
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    /// Day cells for the displayed month; nil = leading/trailing blank.
    private var monthDays: [Date?] {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth) else { return [] }

        let firstWeekday = calendar.component(.weekday, from: displayedMonth)
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7

        var cells: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for day in range {
            cells.append(calendar.date(byAdding: .day, value: day - 1, to: displayedMonth))
        }
        return cells
    }
}

/// Navigation destinations reachable from the diary.
enum DiaryRoute: Hashable {
    case badges
}

/// Single day cell: number + mood emoji marker when a check-in exists.
private struct DiaryDayCell: View {
    let day: Date
    let emoji: String?
    let isSelected: Bool
    let isToday: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 1) {
                Text("\(Calendar.current.component(.day, from: day))")
                    .font(.caption.weight(isToday ? .bold : .medium))
                    .foregroundStyle(isToday ? Theme.primary : Theme.ink)
                if let emoji {
                    Text(emoji)
                        .font(.system(size: 13))
                } else {
                    Circle()
                        .fill(Theme.inkSoft.opacity(0.15))
                        .frame(width: 4, height: 4)
                        .padding(.vertical, 5)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                isSelected ? Theme.primary.opacity(0.14) : .clear,
                in: .rect(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Theme.primary.opacity(0.5) : .clear, lineWidth: 1.5)
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// One check-in inside the day detail: mood, goal and proposed movies.
private struct DiaryCheckInRow: View {
    let checkIn: MoodCheckIn

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(checkIn.mood?.emoji ?? "🎬")
                    .font(.system(size: 22))
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(checkIn.mood?.title ?? "—")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        if checkIn.isQuickPick {
                            Text(L("diary.quick"))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.amber)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.amber.opacity(0.14), in: .capsule)
                        }
                    }
                    Text(checkIn.goal?.title ?? "—")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer()
                Text(timeString)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Theme.inkSoft)
            }

            if !checkIn.proposed.isEmpty {
                Text(LF("diary.proposedList", checkIn.proposed.prefix(3).map(\.title).joined(separator: ", ")))
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(2)
            }
        }
        .padding(10)
        .background(Theme.surface.opacity(0.6), in: .rect(cornerRadius: 12))
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.locale = LocalizationManager.shared.locale
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: checkIn.date)
    }
}

/// Streak flame card with the gentle no-guilt message when interrupted.
struct StreakCard: View {
    let streak: Int
    let wasInterrupted: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("🔥")
                .font(.system(size: 30))
                .opacity(streak > 0 ? 1 : 0.45)

            VStack(alignment: .leading, spacing: 2) {
                if streak > 0 {
                    Text(LF("diary.streak.days", streak))
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText())
                    Text(L("diary.streak.active"))
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                } else if wasInterrupted {
                    Text(L("diary.streak.broken.title"))
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text(L("diary.streak.broken.msg"))
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                } else {
                    Text(L("diary.streak.start.title"))
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text(L("diary.streak.start.msg"))
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            Spacer()
        }
        .padding(16)
        .background(Theme.card, in: .rect(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.primary.opacity(0.10), lineWidth: 1)
        )
    }
}

/// Monday recap of the previous week: top mood + watched movies.
private struct WeeklyRecapCard: View {
    let recap: WeeklyRecap
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(L("diary.recap.title"), systemImage: "sparkles")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.amber)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.inkSoft)
                        .frame(width: 26, height: 26)
                        .background(Theme.surface.opacity(0.7), in: .circle)
                }
                .accessibilityLabel(L("common.ok"))
            }

            Text(recapText)
                .font(.footnote)
                .foregroundStyle(Theme.ink)
                .lineSpacing(3)
        }
        .padding(16)
        .background(Theme.amber.opacity(0.10), in: .rect(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.amber.opacity(0.35), lineWidth: 1)
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var recapText: String {
        var text = LF(
            "diary.recap.mood",
            recap.topMood.title, recap.topMood.emoji, recap.checkInCount
        )
        if recap.watchedCount > 0 {
            text += " " + LF("diary.recap.watched", recap.watchedCount)
            if let title = recap.watchedTitle {
                text += " " + LF("diary.recap.favorite", title)
            }
        }
        return text
    }
}

extension Calendar {
    /// First day of the month containing `date`.
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}

#Preview {
    NavigationStack {
        DiaryView()
    }
    .environment(MoodDiary())
    .environment(MovieLibrary())
}
