//
//  DiaryView.swift
//  MoodE
//

import SwiftUI

/// "Il mio diario": monthly mood calendar, weekly recap, streak and day detail.
struct DiaryView: View {
    @Environment(MoodDiary.self) private var diary
    @Environment(MovieLibrary.self) private var library
    @Environment(MoviePlanner.self) private var planner
    @Environment(NotificationService.self) private var notifications
    @Environment(MovieStatsStore.self) private var statsStore
    @Environment(\.dismiss) private var dismiss

    @State private var displayedMonth: Date
    @State private var selectedDay: Date
    @State private var recap: WeeklyRecap?
    @State private var noteTarget: MoodCheckIn?
    @State private var showScheduleSheet: Bool = false
    @State private var watchedTarget: ScheduledMovie?
    @State private var moveTarget: ScheduledMovie?
    @State private var pendingDeletion: DiaryDeletion?

    /// Opens the diary on a specific day (defaults to today) — used by the
    /// "Un anno fa oggi" card to jump straight to that memory.
    init(initialDay: Date = Date()) {
        _displayedMonth = State(initialValue: Calendar.current.startOfMonth(for: initialDay))
        _selectedDay = State(initialValue: Calendar.current.startOfDay(for: initialDay))
    }

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

                    if let monthly = planner.monthlyRecap(for: Date(), checkIns: diary.checkIns) {
                        MonthlyRecapCard(recap: monthly, monthTitle: currentMonthTitle)
                    }

                    StreakCard(streak: diary.streak, wasInterrupted: diary.streakWasInterrupted) {
                        // Pops back to Home, where a new check-in restarts the streak.
                        dismiss()
                    }

                    ChallengeCard()

                    if !planner.pendingPastScheduled.isEmpty {
                        pendingBanner
                    }

                    calendarCard

                    dayDetail

                    NavigationLink(value: DiaryRoute.memories) {
                        memoriesRow
                    }
                    .buttonStyle(PressableCardStyle())

                    NavigationLink(value: DiaryRoute.stats) {
                        statsRow
                    }
                    .buttonStyle(PressableCardStyle())

                    NavigationLink(value: DiaryRoute.badges) {
                        badgesRow
                    }
                    .buttonStyle(PressableCardStyle())

                    NavigationLink(value: DiaryRoute.friends) {
                        friendsRow
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
        .sheet(item: $noteTarget) { checkIn in
            CheckInNoteEditor(checkIn: checkIn)
        }
        .sheet(isPresented: $showScheduleSheet) {
            ScheduleMovieView(day: selectedDay)
        }
        .sheet(item: $watchedTarget) { plan in
            MarkWatchedSheet(scheduled: plan)
        }
        .sheet(item: $moveTarget) { plan in
            MoveScheduleSheet(scheduled: plan)
        }
        .alert(
            L("diary.movie.remove.title"),
            isPresented: deletionAlertBinding,
            presenting: pendingDeletion
        ) { target in
            Button(L("common.cancel"), role: .cancel) { pendingDeletion = nil }
            Button(L("diary.movie.remove.confirm"), role: .destructive) { delete(target) }
        } message: { _ in
            Text(L("diary.movie.remove.msg"))
        }
    }

    /// Drives the single confirmation alert shared by every delete action.
    private var deletionAlertBinding: Binding<Bool> {
        Binding(
            get: { pendingDeletion != nil },
            set: { isPresented in
                if !isPresented { pendingDeletion = nil }
            }
        )
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
                        hasMovie: planner.hasScheduled(on: day),
                        isPending: planner.hasPendingSchedule(on: day),
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
        let watchedThatDay = watchedItems(on: selectedDay)

        return VStack(alignment: .leading, spacing: 12) {
            Text(dayDetailTitle)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.ink)

            if checkIns.isEmpty && watchedThatDay.isEmpty && !planner.hasScheduled(on: selectedDay) {
                Text(L("diary.day.empty"))
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let plan = planner.scheduledMovie(on: selectedDay) {
                ScheduledMovieCard(
                    plan: plan,
                    isPending: planner.hasPendingSchedule(on: selectedDay),
                    onWatched: { watchedTarget = plan },
                    onMove: { moveTarget = plan },
                    onRemove: { pendingDeletion = .plan(plan) }
                )
            } else {
                Button {
                    showScheduleSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text(L("planner.scheduleButton"))
                            .font(.footnote.weight(.semibold))
                    }
                    .foregroundStyle(Theme.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Theme.primary.opacity(0.08), in: .rect(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Theme.primary.opacity(0.30), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    )
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }

            ForEach(checkIns) { checkIn in
                DiaryCheckInRow(
                    checkIn: checkIn,
                    onEditNote: { noteTarget = checkIn },
                    onRemoveProposed: { movie in
                        pendingDeletion = .proposed(checkInId: checkIn.id, movie: movie)
                    }
                )
            }

            if !watchedThatDay.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label(L("diary.day.watched"), systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.seenGreen)
                    ForEach(watchedThatDay) { item in
                        DiaryMovieRow(
                            movie: item.movie,
                            role: .watched,
                            badge: item.ratingEmoji
                        ) {
                            pendingDeletion = .watched(item)
                        }
                    }
                }
                .padding(.top, 2)
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

    // MARK: - Pending banner

    /// Tappable notice listing how many past plans still need to be marked
    /// as watched; tapping jumps the calendar to the oldest one.
    private var pendingBanner: some View {
        let pending = planner.pendingPastScheduled
        return Button {
            guard let oldest = pending.first else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                displayedMonth = Calendar.current.startOfMonth(for: oldest.day)
                selectedDay = oldest.day
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.amber)
                    .symbolRenderingMode(.hierarchical)

                Text(
                    pending.count == 1
                        ? L("planner.pending.one")
                        : LF("planner.pending.many", pending.count)
                )
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.amber)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Theme.amber.opacity(0.12), in: .rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.amber.opacity(0.35), lineWidth: 1)
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func removePlan(_ plan: ScheduledMovie) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            planner.removeSchedule(plan.id)
        }
        notifications.syncMovieNightReminders(planner.scheduled)
    }

    // MARK: - Watched movies of the day

    /// Every movie watched on `day`, merging the saved memories (which keep
    /// the planned day even when marked as watched later) with the general
    /// "Già visti" list, minus the references the user removed by hand.
    /// A movie marked as watched therefore stays in its day forever.
    private func watchedItems(on day: Date) -> [DiaryWatchedItem] {
        let calendar = Calendar.current
        let dayMemories = planner.memories(on: day)
        var items: [DiaryWatchedItem] = dayMemories.map {
            DiaryWatchedItem(
                movie: $0.asMovie,
                memoryId: $0.id,
                ratingEmoji: $0.ratingEmoji,
                day: day
            )
        }

        let covered = Set(dayMemories.map(\.movieId))
        for entry in library.watched {
            guard let date = entry.watchedDate,
                  calendar.isDate(date, inSameDayAs: day),
                  !covered.contains(entry.id) else { continue }
            items.append(
                DiaryWatchedItem(movie: entry.asMovie, memoryId: nil, ratingEmoji: nil, day: day)
            )
        }

        return items.filter { !planner.isHiddenFromDiary(movieId: $0.movie.id, on: day) }
    }

    /// Applies a confirmed deletion. It only ever removes the reference from
    /// that diary day: watchlist entries are never touched.
    private func delete(_ target: DiaryDeletion) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            switch target {
            case .plan(let plan):
                removePlan(plan)
            case .proposed(let checkInId, let movie):
                diary.removeProposed(movieId: movie.id, from: checkInId)
            case .watched(let item):
                if let memoryId = item.memoryId {
                    planner.removeMemory(memoryId)
                }
                planner.hideFromDiary(movieId: item.movie.id, on: item.day)
            }
        }
        pendingDeletion = nil
    }

    // MARK: - Memories row

    private var memoriesRow: some View {
        HStack(spacing: 12) {
            Text("🎞️")
                .font(.system(size: 26))
            VStack(alignment: .leading, spacing: 2) {
                Text(L("memories.row.title"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(LF("memories.row.subtitle", planner.memories.count))
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
                .stroke(Theme.rose.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(spacing: 12) {
            Text("\u{1F4CA}")
                .font(.system(size: 26))
            VStack(alignment: .leading, spacing: 2) {
                Text(L("stats.title"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(L("stats.row.subtitle"))
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
                .stroke(Theme.primary.opacity(0.20), lineWidth: 1)
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

    // MARK: - Friends row

    private var friendsRow: some View {
        HStack(spacing: 12) {
            Text("\u{1F3C6}")
                .font(.system(size: 26))
            VStack(alignment: .leading, spacing: 2) {
                Text(L("friends.row.title"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(L("friends.row.subtitle"))
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
                .stroke(Theme.tabList.opacity(0.30), lineWidth: 1)
        )
    }

    private var badgesSubtitle: String {
        let stats = diary.stats(
            watchedTotal: library.lifetimeWatchedCount,
            genreWatched: statsStore.genreCounts(watched: library.watched, memories: planner.memories)
        )
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

    private var currentMonthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = LocalizationManager.shared.locale
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: Date()).capitalized
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

/// A movie watched on a given diary day, coming either from a saved memory
/// (with its emoji rating) or from the general "Già visti" list. Both open
/// the very same movie detail page.
struct DiaryWatchedItem: Identifiable, Hashable {
    let movie: TMDBMovie
    let memoryId: UUID?
    let ratingEmoji: String?
    let day: Date

    var id: Int { movie.id }
}

/// A diary reference waiting for the user's delete confirmation.
enum DiaryDeletion: Identifiable {
    case plan(ScheduledMovie)
    case proposed(checkInId: UUID, movie: ProposedMovie)
    case watched(DiaryWatchedItem)

    var id: String {
        switch self {
        case .plan(let plan):
            return "plan-\(plan.id.uuidString)"
        case .proposed(let checkInId, let movie):
            return "proposed-\(checkInId.uuidString)-\(movie.id)"
        case .watched(let item):
            return "watched-\(item.movie.id)"
        }
    }
}

/// Navigation destinations reachable from the diary.
enum DiaryRoute: Hashable {
    case badges
    case memories
    case stats
    case friends
}

/// Single day cell: number, mood emoji marker for check-ins, and a small
/// clapper marker when a movie is planned. Both can coexist. A small amber
/// badge appears on past days whose movie was never marked as watched.
private struct DiaryDayCell: View {
    let day: Date
    let emoji: String?
    let hasMovie: Bool
    let isPending: Bool
    let isSelected: Bool
    let isToday: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 1) {
                Text("\(Calendar.current.component(.day, from: day))")
                    .font(.caption.weight(isToday ? .bold : .medium))
                    .foregroundStyle(isToday ? Theme.primary : Theme.ink)
                if emoji != nil || hasMovie {
                    HStack(spacing: 1) {
                        if let emoji {
                            Text(emoji)
                                .font(.system(size: hasMovie ? 11 : 13))
                        }
                        if hasMovie {
                            Text("🎬")
                                .font(.system(size: emoji == nil ? 12 : 9))
                        }
                    }
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
            .overlay(alignment: .topTrailing) {
                if isPending {
                    Circle()
                        .fill(Theme.amber)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle().stroke(Theme.card, lineWidth: 1.5)
                        )
                        .padding(4)
                        .transition(.scale.combined(with: .opacity))
                        .accessibilityLabel(L("planner.pending.one"))
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// Planned movie inside the day detail: poster, title and the three
/// actions (watched → memory form, move to another day, remove).
private struct ScheduledMovieCard: View {
    let plan: ScheduledMovie
    let isPending: Bool
    let onWatched: () -> Void
    let onMove: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(L("planner.scheduled"), systemImage: "movieclapper")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.rose)

            if isPending {
                HStack(spacing: 6) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                    Text(L("planner.pendingHint"))
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(Theme.amber)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.amber.opacity(0.12), in: .rect(cornerRadius: 9))
            }

            HStack(alignment: .top, spacing: 4) {
                NavigationLink(value: plan.asMovie) {
                    HStack(spacing: 10) {
                        poster
                        VStack(alignment: .leading, spacing: 4) {
                            Text(plan.title)
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(Theme.ink)
                                .underline(true, color: Theme.rose.opacity(0.45))
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)
                            HStack(spacing: 3) {
                                Text(L("diary.movie.open"))
                                    .font(.caption2.weight(.semibold))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 8, weight: .bold))
                            }
                            .foregroundStyle(Theme.rose)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(DiaryLinkButtonStyle(accent: Theme.rose))

                DiaryMovieMenu(onDelete: onRemove)
            }

            Button(action: onWatched) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text(L("planner.markWatched"))
                        .font(.footnote.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(Theme.seenGreen, in: .rect(cornerRadius: 11))
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                Button(action: onMove) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.right.circle")
                            .font(.system(size: 11, weight: .semibold))
                        Text(L("planner.move"))
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(Theme.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(Theme.primary.opacity(0.10), in: .capsule)
                    .contentShape(.capsule)
                }
                .buttonStyle(.plain)

                Button(action: onRemove) {
                    HStack(spacing: 5) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 11, weight: .semibold))
                        Text(L("planner.remove"))
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(Theme.rose)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(Theme.rose.opacity(0.10), in: .capsule)
                    .contentShape(.capsule)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Theme.surface.opacity(0.6), in: .rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.rose.opacity(0.25), lineWidth: 1)
        )
    }

    private var poster: some View {
        Group {
            if let url = plan.posterURL {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Theme.surface
                }
            } else {
                Theme.surface.overlay { Text("🎬") }
            }
        }
        .frame(width: 46, height: 69)
        .clipShape(.rect(cornerRadius: 8))
    }
}

/// One check-in inside the day detail: mood, goal, proposed movies and
/// the optional personal note with its add/edit button.
private struct DiaryCheckInRow: View {
    let checkIn: MoodCheckIn
    let onEditNote: () -> Void
    let onRemoveProposed: (ProposedMovie) -> Void

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
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("diary.proposed.header"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.inkSoft)
                        .padding(.leading, 6)
                    ForEach(checkIn.proposed) { movie in
                        DiaryMovieRow(movie: movie.asMovie, role: .proposed) {
                            onRemoveProposed(movie)
                        }
                    }
                }
                .padding(.top, 2)
            }

            if let note = checkIn.note {
                HStack(alignment: .top, spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.primary.opacity(0.45))
                        .frame(width: 3)
                    Text(note)
                        .font(.footnote.italic())
                        .foregroundStyle(Theme.ink.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, 2)
            }

            Button(action: onEditNote) {
                HStack(spacing: 5) {
                    Image(systemName: checkIn.note == nil ? "square.and.pencil" : "pencil")
                        .font(.system(size: 11, weight: .semibold))
                    Text(checkIn.note == nil ? L("diary.note.add") : L("diary.note.edit"))
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(Theme.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Theme.primary.opacity(0.10), in: .capsule)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
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
/// When the streak is at zero it becomes tappable and jumps back to Home
/// so a fresh check-in can restart it right away.
struct StreakCard: View {
    let streak: Int
    let wasInterrupted: Bool
    var onRestart: (() -> Void)? = nil

    var body: some View {
        if streak == 0, let onRestart {
            Button(action: onRestart) {
                cardContent
                    .contentShape(.rect)
            }
            .buttonStyle(PressableCardStyle())
            .accessibilityHint(L("diary.streak.restart"))
        } else {
            cardContent
        }
    }

    private var cardContent: some View {
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

            if streak == 0, onRestart != nil {
                HStack(spacing: 4) {
                    Text(L("diary.streak.restart"))
                        .font(.caption.weight(.semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(Theme.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.primary.opacity(0.12), in: .capsule)
            }
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

/// Small sheet to write or edit the personal note of a check-in.
private struct CheckInNoteEditor: View {
    let checkIn: MoodCheckIn

    @Environment(MoodDiary.self) private var diary
    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @State private var didSave: Bool = false
    @FocusState private var isFocused: Bool

    private static let maxLength = 180

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Text(checkIn.mood?.emoji ?? "🎬")
                            .font(.system(size: 24))
                        Text(checkIn.mood?.title ?? "—")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        Text("\(text.count)/\(Self.maxLength)")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(text.count >= Self.maxLength ? Theme.rose : Theme.inkSoft)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }

                    TextField(L("diary.note.placeholder"), text: $text, axis: .vertical)
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink)
                        .lineLimit(4...7)
                        .focused($isFocused)
                        .padding(12)
                        .background(Theme.card, in: .rect(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Theme.primary.opacity(0.18), lineWidth: 1)
                        )
                        .onChange(of: text) { _, newValue in
                            if newValue.count > Self.maxLength {
                                text = String(newValue.prefix(Self.maxLength))
                            }
                        }

                    Button {
                        diary.setNote(text, for: checkIn.id)
                        didSave.toggle()
                        dismiss()
                    } label: {
                        Text(L("diary.note.save"))
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Theme.primary, in: .rect(cornerRadius: 14))
                    }
                    .sensoryFeedback(.success, trigger: didSave)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            .navigationTitle(L("diary.note.title"))
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("common.cancel")) { dismiss() }
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
        }
        .presentationDetents([.height(320), .medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            text = checkIn.note ?? ""
            isFocused = true
        }
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
    .environment(MoviePlanner())
    .environment(NotificationService())
    .environment(MovieStatsStore())
}
