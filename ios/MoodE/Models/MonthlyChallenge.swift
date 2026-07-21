//
//  MonthlyChallenge.swift
//  MoodE
//

import Foundation

/// What the monthly challenge asks the user to do, with its target.
/// Every kind is measurable from data already stored on the device.
enum ChallengeKind: Hashable {
    /// Watch N movies this month.
    case watch(Int)
    /// Record N distinct moods this month.
    case moods(Int)
    /// Explore N moods outside the user's all-time top 3.
    case rare(Int)
    /// Check in on N distinct days this month.
    case days(Int)
    /// Explore N distinct viewing goals this month.
    case goals(Int)

    var target: Int {
        switch self {
        case .watch(let n), .moods(let n), .rare(let n), .days(let n), .goals(let n):
            return n
        }
    }

    /// Localization key fragment.
    var key: String {
        switch self {
        case .watch: return "watch"
        case .moods: return "moods"
        case .rare: return "rare"
        case .days: return "days"
        case .goals: return "goals"
        }
    }
}

/// Progress toward the active challenge, computed from local data only.
struct ChallengeProgress {
    let value: Int
    let target: Int

    var fraction: Double { min(Double(value) / Double(max(target, 1)), 1) }
    var isComplete: Bool { value >= target }
}

/// The challenge active in a given month.
struct MonthlyChallenge: Identifiable {
    /// Month key, e.g. "2026-07". Also the completion-tracking key.
    let id: String
    let emoji: String
    let kind: ChallengeKind

    var title: String { L("challenge.\(kind.key).title") }
    var detail: String { LF("challenge.\(kind.key).desc", kind.target) }
}

/// Central monthly-challenge calendar: the single place to edit the
/// rotation (same approach as `FeaturedCalendar` for editorial themes).
enum ChallengeCalendar {
    /// Editorial rotation January (1) → December (12).
    private static let byMonth: [Int: (emoji: String, kind: ChallengeKind)] = [
        1: ("🎯", .days(10)),
        2: ("💞", .moods(4)),
        3: ("🍿", .watch(4)),
        4: ("🦋", .rare(3)),
        5: ("🎭", .goals(4)),
        6: ("📽️", .watch(5)),
        7: ("🌈", .moods(5)),
        8: ("🗓️", .days(12)),
        9: ("🧭", .rare(3)),
        10: ("🎃", .watch(4)),
        11: ("✨", .goals(5)),
        12: ("🎄", .days(10))
    ]

    /// The challenge for the month containing `date`.
    static func current(for date: Date = Date()) -> MonthlyChallenge {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let year = calendar.component(.year, from: date)
        let config = byMonth[month] ?? ("🎬", .watch(3))
        return MonthlyChallenge(
            id: String(format: "%04d-%02d", year, month),
            emoji: config.emoji,
            kind: config.kind
        )
    }
}

extension MonthlyChallenge {
    /// Progress computed from the diary, library and memories — all local.
    func progress(
        diary: MoodDiary,
        library: MovieLibrary,
        planner: MoviePlanner,
        now: Date = Date()
    ) -> ChallengeProgress {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: now) else {
            return ChallengeProgress(value: 0, target: kind.target)
        }

        let monthCheckIns = diary.checkIns.filter { interval.contains($0.date) }

        let value: Int
        switch kind {
        case .watch:
            var ids = Set(
                library.watched
                    .filter { entry in
                        guard let date = entry.watchedDate else { return false }
                        return interval.contains(date)
                    }
                    .map(\.id)
            )
            ids.formUnion(
                planner.memories
                    .filter { interval.contains($0.watchedDate) }
                    .map(\.movieId)
            )
            value = ids.count

        case .moods:
            value = Set(monthCheckIns.map(\.moodRaw)).count

        case .rare:
            // Top-3 moods before this month = the "usual" ones.
            var counts: [String: Int] = [:]
            for checkIn in diary.checkIns where checkIn.date < interval.start {
                counts[checkIn.moodRaw, default: 0] += 1
            }
            let usual = Set(counts.sorted { $0.value > $1.value }.prefix(3).map(\.key))
            value = Set(monthCheckIns.map(\.moodRaw)).subtracting(usual).count

        case .days:
            value = Set(monthCheckIns.map { calendar.startOfDay(for: $0.date) }).count

        case .goals:
            value = Set(monthCheckIns.map(\.goalRaw)).count
        }

        return ChallengeProgress(value: value, target: kind.target)
    }
}
