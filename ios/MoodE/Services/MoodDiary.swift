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

    var id: String { rawValue }

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

    private let defaults = UserDefaults.standard

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.checkInsKey),
           let stored = try? JSONDecoder().decode([MoodCheckIn].self, from: data) {
            checkIns = stored.sorted { $0.date > $1.date }
        } else {
            checkIns = []
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
        }

        persist()
        publishWidgetSnapshot()
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(checkIns)
            defaults.set(data, forKey: Self.checkInsKey)
        } catch {
            print("MoodDiary: persist failed: \(error.localizedDescription)")
        }
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
        let days = Set(checkIns.map { calendar.startOfDay(for: $0.date) })
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
        let days = Set(checkIns.map { calendar.startOfDay(for: $0.date) }).sorted()
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
        streak == 0 && !checkIns.isEmpty
    }

    // MARK: - Stats & badges

    func stats(watchedTotal: Int) -> DiaryStats {
        let calendar = Calendar.current
        let hours = checkIns.map { calendar.component(.hour, from: $0.date) }
        return DiaryStats(
            checkInCount: checkIns.count,
            distinctMoods: Set(checkIns.map(\.moodRaw)).count,
            watchedTotal: watchedTotal,
            nightCheckIns: hours.filter { $0 >= 22 || $0 < 4 }.count,
            morningCheckIns: hours.filter { $0 >= 5 && $0 < 9 }.count,
            bestStreak: bestStreak
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

    /// Writes the latest mood + a matching movie into the shared container
    /// and asks WidgetKit to refresh the home-screen widget.
    func publishWidgetSnapshot() {
        guard let latest = checkIns.first, let mood = latest.mood else { return }
        let movie = latest.proposed.first

        let snapshot = DiaryWidgetSnapshot(
            moodEmoji: mood.emoji,
            moodTitle: mood.title,
            headline: L("widget.forYou"),
            movieId: movie?.id,
            movieTitle: movie?.title,
            posterPath: movie?.posterPath,
            updatedAt: Date()
        )

        guard let shared = UserDefaults(suiteName: Self.appGroupID),
              let data = try? JSONEncoder().encode(snapshot) else { return }
        shared.set(data, forKey: Self.widgetSnapshotKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
