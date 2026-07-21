//
//  MoodDiary.swift
//  MoodE
//

import Foundation
import Observation
import WidgetKit

/// Achievements unlocked by using the diary. Personal only: no leaderboards.
enum Badge: String, CaseIterable, Identifiable {
    case primoPasso, primaSettimana, esploratore, cinefilo
    case nottambulo, mattiniero, fiammaViva, collezionista
    case buonConsigliere, parteDellaCommunity
    case esploratoreHorror, amanteDelDramma, reDellaCommedia
    case animatore, documentarista

    var id: String { rawValue }

    /// Genre-based milestone (TMDB genre id + watched target), when applicable.
    var genreGoal: (genreId: Int, target: Int)? {
        switch self {
        case .esploratoreHorror: return (27, 5)
        case .amanteDelDramma: return (18, 10)
        case .reDellaCommedia: return (35, 10)
        case .animatore: return (16, 5)
        case .documentarista: return (99, 3)
        default: return nil
        }
    }

    var title: String { L("badge.\(rawValue).title") }
    var detail: String { L("badge.\(rawValue).desc") }

    var emoji: String {
        switch self {
        case .primoPasso: return "🎬"
        case .primaSettimana: return "📅"
        case .esploratore: return "🧭"
        case .cinefilo: return "🍿"
        case .nottambulo: return "🌙"
        case .mattiniero: return "🌅"
        case .fiammaViva: return "🔥"
        case .collezionista: return "🏆"
        case .buonConsigliere: return "🤝"
        case .parteDellaCommunity: return "💬"
        case .esploratoreHorror: return "👻"
        case .amanteDelDramma: return "🎭"
        case .reDellaCommedia: return "😂"
        case .animatore: return "🎨"
        case .documentarista: return "🎥"
        }
    }

    /// Whether the badge is unlocked given the diary/library stats.
    func isUnlocked(_ stats: DiaryStats) -> Bool {
        switch self {
        case .primoPasso: return stats.checkInCount >= 1
        case .primaSettimana: return stats.checkInCount >= 7
        case .esploratore: return stats.distinctMoods >= 8
        case .cinefilo: return stats.watchedTotal >= 10
        case .nottambulo: return stats.nightCheckIns >= 5
        case .mattiniero: return stats.morningCheckIns >= 5
        case .fiammaViva: return stats.bestStreak >= 7
        case .collezionista: return stats.checkInCount >= 30
        case .buonConsigliere: return stats.helpfulGiven >= 5
        case .parteDellaCommunity: return stats.requestsPublished >= 1
        case .esploratoreHorror, .amanteDelDramma, .reDellaCommedia, .animatore, .documentarista:
            guard let goal = genreGoal else { return false }
            return stats.genreWatched[goal.genreId, default: 0] >= goal.target
        }
    }

    /// Progress 0...1 toward unlocking, for the badge grid.
    func progress(_ stats: DiaryStats) -> Double {
        let ratio: Double
        switch self {
        case .primoPasso: ratio = Double(stats.checkInCount) / 1
        case .primaSettimana: ratio = Double(stats.checkInCount) / 7
        case .esploratore: ratio = Double(stats.distinctMoods) / 8
        case .cinefilo: ratio = Double(stats.watchedTotal) / 10
        case .nottambulo: ratio = Double(stats.nightCheckIns) / 5
        case .mattiniero: ratio = Double(stats.morningCheckIns) / 5
        case .fiammaViva: ratio = Double(stats.bestStreak) / 7
        case .collezionista: ratio = Double(stats.checkInCount) / 30
        case .buonConsigliere: ratio = Double(stats.helpfulGiven) / 5
        case .parteDellaCommunity: ratio = Double(stats.requestsPublished) / 1
        case .esploratoreHorror, .amanteDelDramma, .reDellaCommedia, .animatore, .documentarista:
            guard let goal = genreGoal else { return 0 }
            ratio = Double(stats.genreWatched[goal.genreId, default: 0]) / Double(goal.target)
        }
        return min(ratio, 1)
    }
}

/// Aggregated numbers used to evaluate badges.
struct DiaryStats {
    let checkInCount: Int
    let distinctMoods: Int
    let watchedTotal: Int
    let nightCheckIns: Int
    let morningCheckIns: Int
    let bestStreak: Int
    /// Replies given on the community board that were marked as helpful.
    let helpfulGiven: Int
    /// Advice requests published on the community board.
    let requestsPublished: Int
    /// Watched movies per TMDB genre id, for the genre milestones.
    let genreWatched: [Int: Int]
}

/// Summary of the previous week, shown once at the start of a new week.
struct WeeklyRecap {
    let topMood: Mood
    let checkInCount: Int
    let watchedCount: Int
    let watchedTitle: String?
}

/// Local, account-free emotional diary. Records every completed mood flow,
/// computes the streak and feeds the home-screen widget via the App Group.
@Observable
final class MoodDiary {
    static let appGroupID = "group.app.rork.d9jknb2uwvfyntp4w88dj"
    static let widgetSnapshotKey = "widget.snapshot"
    static let widgetKind = "MoodEWidget"

    private(set) var checkIns: [MoodCheckIn]

    private static let checkInsKey = "diary.checkIns"
    private static let genreAffinityKey = "diary.genreAffinity"
    private static let lastRecapWeekKey = "diary.lastRecapWeek"
    private static let communityDaysKey = "diary.communityDays"

    /// Days with at least one community action (asking or giving advice):
    /// they count toward the streak exactly like emotional check-ins.
    private(set) var communityDays: Set<Date>

    private let defaults = UserDefaults.standard

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.checkInsKey),
           let stored = try? JSONDecoder().decode([MoodCheckIn].self, from: data) {
            checkIns = stored.sorted { $0.date > $1.date }
        } else {
            checkIns = []
        }
        if let data = UserDefaults.standard.data(forKey: Self.communityDaysKey),
           let stored = try? JSONDecoder().decode([Date].self, from: data) {
            communityDays = Set(stored)
        } else {
            communityDays = []
        }
    }

    /// Records today as a community-action day (ask/give advice) for the streak.
    func recordCommunityAction() {
        let today = Calendar.current.startOfDay(for: Date())
        guard !communityDays.contains(today) else { return }
        communityDays.insert(today)
        if let data = try? JSONEncoder().encode(Array(communityDays)) {
            defaults.set(data, forKey: Self.communityDaysKey)
        }
    }

    // MARK: - Recording

    /// Records a completed flow. One check-in per (day, mood, goal): repeating
    /// the same flow on the same day only refreshes the proposed movies.
    func record(selection: MoodSelection, proposed movies: [TMDBMovie]) {
        let calendar = Calendar.current
        let proposed = movies.prefix(8).map {
            ProposedMovie(id: $0.id, title: $0.title, posterPath: $0.posterPath, genreIds: $0.genreIds)
        }

        if let index = checkIns.firstIndex(where: {
            calendar.isDate($0.date, inSameDayAs: Date())
                && $0.moodRaw == selection.mood.rawValue
                && $0.goalRaw == selection.goal.rawValue
        }) {
            checkIns[index].proposed = Array(proposed)
        } else {
            let checkIn = MoodCheckIn(
                id: UUID(),
                date: Date(),
                moodRaw: selection.mood.rawValue,
                goalRaw: selection.goal.rawValue,
                eraRaw: selection.era.rawValue,
                isQuickPick: selection.isQuickPick,
                proposed: Array(proposed)
            )
            checkIns.insert(checkIn, at: 0)
            bumpGenreAffinity(for: Array(proposed))
            AnalyticsService.shared.log("diary_check_in")
        }

        persist()
        publishWidgetSnapshot()
    }

    /// Sets, edits or clears (empty text → nil) the personal note of a check-in.
    func setNote(_ note: String, for id: UUID) {
        guard let index = checkIns.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        checkIns[index].note = trimmed.isEmpty ? nil : trimmed
        persist()
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(checkIns)
            defaults.set(data, forKey: Self.checkInsKey)
        } catch {
            print("MoodDiary: persist failed: \(error.localizedDescription)")
        }
        CloudSyncService.shared.noteLocalChange()
    }

    /// Replaces the whole diary with the cloud-merged copy (sync only).
    func replaceAll(_ merged: [MoodCheckIn]) {
        checkIns = merged.sorted { $0.date > $1.date }
        persist()
        publishWidgetSnapshot()
    }

    // MARK: - Calendar queries

    /// Check-ins on a specific day, newest first.
    func checkIns(on day: Date) -> [MoodCheckIn] {
        let calendar = Calendar.current
        return checkIns.filter { calendar.isDate($0.date, inSameDayAs: day) }
    }

    /// Emoji of the most recent check-in on a day, for the calendar cell.
    func moodEmoji(on day: Date) -> String? {
        checkIns(on: day).first?.mood?.emoji
    }

    // MARK: - Streak

    /// Consecutive days (ending today or yesterday) with at least one check-in.
    var streak: Int {
        let calendar = Calendar.current
        var days = Set(checkIns.map { calendar.startOfDay(for: $0.date) })
        days.formUnion(communityDays.map { calendar.startOfDay(for: $0) })
        guard !days.isEmpty else { return 0 }

        var day = calendar.startOfDay(for: Date())
        if !days.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day),
                  days.contains(yesterday) else { return 0 }
            day = yesterday
        }

        var count = 0
        while days.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    /// Longest streak ever, for the "Fiamma viva" badge.
    var bestStreak: Int {
        let calendar = Calendar.current
        var daySet = Set(checkIns.map { calendar.startOfDay(for: $0.date) })
        daySet.formUnion(communityDays.map { calendar.startOfDay(for: $0) })
        let days = daySet.sorted()
        guard !days.isEmpty else { return 0 }

        var best = 1
        var current = 1
        for index in 1..<days.count {
            let expected = calendar.date(byAdding: .day, value: 1, to: days[index - 1])
            if let expected, calendar.isDate(days[index], inSameDayAs: expected) {
                current += 1
                best = max(best, current)
            } else {
                current = 1
            }
        }
        return best
    }

    /// True when a previous streak just ended: used for the gentle,
    /// guilt-free "restart whenever you like" message.
    var streakWasInterrupted: Bool {
        streak == 0 && !(checkIns.isEmpty && communityDays.isEmpty)
    }

    /// Most frequent mood of the last 30 days, used for the community
    /// "people feel like you" daily notification. Nil with no history.
    var topMood: Mood? {
        let calendar = Calendar.current
        guard let monthAgo = calendar.date(byAdding: .day, value: -30, to: Date()) else { return nil }
        let recent = checkIns.filter { $0.date >= monthAgo }
        guard !recent.isEmpty else { return nil }
        var counts: [String: Int] = [:]
        for checkIn in recent {
            counts[checkIn.moodRaw, default: 0] += 1
        }
        guard let top = counts.max(by: { $0.value < $1.value })?.key else { return nil }
        return Mood(rawValue: top)
    }

    // MARK: - Stats & badges

    func stats(watchedTotal: Int, genreWatched: [Int: Int] = [:]) -> DiaryStats {
        let calendar = Calendar.current
        let hours = checkIns.map { calendar.component(.hour, from: $0.date) }
        return DiaryStats(
            checkInCount: checkIns.count,
            distinctMoods: Set(checkIns.map(\.moodRaw)).count,
            watchedTotal: watchedTotal,
            nightCheckIns: hours.filter { $0 >= 22 || $0 < 4 }.count,
            morningCheckIns: hours.filter { $0 >= 5 && $0 < 9 }.count,
            bestStreak: bestStreak,
            helpfulGiven: defaults.integer(forKey: CommunityService.helpfulReceivedKey),
            requestsPublished: defaults.integer(forKey: CommunityService.requestsPublishedKey),
            genreWatched: genreWatched
        )
    }

    // MARK: - Weekly recap

    /// Recap of the previous week, ready to show at the first access of a new week.
    /// Returns nil once dismissed (or when the previous week has no check-ins).
    func pendingWeeklyRecap(watched: [LibraryEntry]) -> WeeklyRecap? {
        let currentWeek = Self.weekKey(for: Date())
        guard defaults.string(forKey: Self.lastRecapWeekKey) != currentWeek else { return nil }

        let calendar = Calendar.current
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) else { return nil }
        guard let previousWeekInterval = calendar.dateInterval(of: .weekOfYear, for: weekAgo) else { return nil }

        let weekCheckIns = checkIns.filter { previousWeekInterval.contains($0.date) }
        guard !weekCheckIns.isEmpty else { return nil }

        var moodCounts: [String: Int] = [:]
        for checkIn in weekCheckIns {
            moodCounts[checkIn.moodRaw, default: 0] += 1
        }
        guard let topMoodRaw = moodCounts.max(by: { $0.value < $1.value })?.key,
              let topMood = Mood(rawValue: topMoodRaw) else { return nil }

        let watchedThatWeek = watched.filter {
            guard let date = $0.watchedDate else { return false }
            return previousWeekInterval.contains(date)
        }

        return WeeklyRecap(
            topMood: topMood,
            checkInCount: weekCheckIns.count,
            watchedCount: watchedThatWeek.count,
            watchedTitle: watchedThatWeek.first?.title
        )
    }

    /// Marks the current week's recap as seen.
    func dismissWeeklyRecap() {
        defaults.set(Self.weekKey(for: Date()), forKey: Self.lastRecapWeekKey)
    }

    private static func weekKey(for date: Date) -> String {
        let calendar = Calendar.current
        let week = calendar.component(.weekOfYear, from: date)
        let year = calendar.component(.yearForWeekOfYear, from: date)
        return "\(year)-W\(week)"
    }

    // MARK: - Genre affinity (for release notifications)

    private func bumpGenreAffinity(for proposed: [ProposedMovie]) {
        var counts = (defaults.dictionary(forKey: Self.genreAffinityKey) as? [String: Int]) ?? [:]
        for movie in proposed {
            for genre in movie.genreIds ?? [] {
                counts["\(genre)", default: 0] += 1
            }
        }
        defaults.set(counts, forKey: Self.genreAffinityKey)
    }

    /// The user's most recurring genres (last month of choices), used to
    /// prioritize new-release notifications. Empty when history is thin.
    var topGenreIds: [Int] {
        let calendar = Calendar.current
        guard let monthAgo = calendar.date(byAdding: .month, value: -1, to: Date()) else { return [] }
        let recent = checkIns.filter { $0.date >= monthAgo }
        guard recent.count >= 3 else { return [] }

        var counts: [Int: Int] = [:]
        for checkIn in recent {
            for movie in checkIn.proposed {
                for genre in movie.genreIds ?? [] {
                    counts[genre, default: 0] += 1
                }
            }
        }
        return counts.sorted { $0.value > $1.value }.prefix(5).map(\.key)
    }

    // MARK: - Widget

    /// Writes the latest mood + a matching movie + the user's most-used
    /// moods (for the interactive widget) into the shared container and
    /// asks WidgetKit to refresh the home-screen widget.
    func publishWidgetSnapshot() {
        let latest = checkIns.first
        let mood = latest?.mood
        let movie = latest?.proposed.first

        let snapshot = DiaryWidgetSnapshot(
            moodEmoji: mood?.emoji ?? "\u{1F3AC}",
            moodTitle: mood?.title ?? "Mood-E",
            headline: L("widget.forYou"),
            movieId: movie?.id,
            movieTitle: movie?.title,
            posterPath: movie?.posterPath,
            updatedAt: Date(),
            quickTitle: L("widget.quick.title"),
            quickMoods: quickMoodRanking.map {
                WidgetQuickMood(raw: $0.rawValue, emoji: $0.emoji, title: $0.title)
            }
        )

        guard let shared = UserDefaults(suiteName: Self.appGroupID),
              let data = try? JSONEncoder().encode(snapshot) else { return }
        shared.set(data, forKey: Self.widgetSnapshotKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// The 6 moods the user picks most often (last 120 check-ins),
    /// padded with a friendly default set for new users.
    var quickMoodRanking: [Mood] {
        var counts: [String: Int] = [:]
        for checkIn in checkIns.prefix(120) {
            counts[checkIn.moodRaw, default: 0] += 1
        }
        var result = counts
            .sorted { $0.value > $1.value }
            .compactMap { Mood(rawValue: $0.key) }
        let defaults: [Mood] = [.felice, .triste, .stressato, .annoiato, .curioso, .innamorato]
        for mood in defaults where !result.contains(mood) {
            result.append(mood)
        }
        return Array(result.prefix(6))
    }
}
