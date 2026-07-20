//
//  MoodForecast.swift
//  MoodE
//

import Foundation

/// Recurring weekday-mood pattern detected in the local diary,
/// used to schedule the proactive "mood forecast" notification.
struct ForecastPattern: Hashable {
    /// `Calendar` weekday (1 = Sunday ... 7 = Saturday).
    let weekday: Int
    let moodRaw: String
    let goalRaw: String
    /// Typical check-in hour for that weekday (median of the history).
    let hour: Int
    let minute: Int
}

/// Pure local analysis of the diary history: no data leaves the device.
enum MoodForecastAnalyzer {
    /// Minimum diary age before forecasts activate (avoids premature patterns).
    static let minimumHistoryDays = 21
    /// Minimum occurrences of the same weekday-mood pair.
    static let minimumOccurrences = 2
    /// Only the recent past is considered, so old habits fade out.
    private static let windowWeeks = 8

    /// Detects, for each weekday, the dominating mood of the recent weeks.
    static func patterns(from checkIns: [MoodCheckIn], now: Date = Date()) -> [ForecastPattern] {
        let calendar = Calendar.current
        guard let oldest = checkIns.map(\.date).min(),
              let threshold = calendar.date(byAdding: .day, value: -minimumHistoryDays, to: now),
              oldest <= threshold else { return [] }

        guard let windowStart = calendar.date(byAdding: .weekOfYear, value: -windowWeeks, to: now) else {
            return []
        }
        let recent = checkIns.filter { $0.date >= windowStart }

        var byWeekday: [Int: [MoodCheckIn]] = [:]
        for checkIn in recent {
            byWeekday[calendar.component(.weekday, from: checkIn.date), default: []].append(checkIn)
        }

        var patterns: [ForecastPattern] = []
        for (weekday, entries) in byWeekday {
            var moodCounts: [String: Int] = [:]
            for entry in entries {
                moodCounts[entry.moodRaw, default: 0] += 1
            }
            guard let top = moodCounts.max(by: { ($0.value, $1.key) < ($1.value, $0.key) }),
                  top.value >= minimumOccurrences else { continue }

            let matching = entries.filter { $0.moodRaw == top.key }
            let hours = matching.map { calendar.component(.hour, from: $0.date) }.sorted()
            let typicalHour = hours[hours.count / 2]

            // Most frequent goal chosen with that mood in this context.
            var goalCounts: [String: Int] = [:]
            for entry in matching {
                goalCounts[entry.goalRaw, default: 0] += 1
            }
            let goal = goalCounts.max { ($0.value, $1.key) < ($1.value, $0.key) }?.key
                ?? Mood(rawValue: top.key)?.quickPickGoal.rawValue
                ?? ViewingGoal.distrarmi.rawValue

            patterns.append(ForecastPattern(
                weekday: weekday,
                moodRaw: top.key,
                goalRaw: goal,
                hour: min(max(typicalHour, 8), 22),
                minute: 0
            ))
        }
        return patterns.sorted { $0.weekday < $1.weekday }
    }

    /// Localized weekday name ("lunedì", "Monday", ...) for the notification body.
    static func weekdayName(_ weekday: Int) -> String {
        var calendar = Calendar.current
        calendar.locale = LocalizationManager.shared.locale
        let symbols = calendar.weekdaySymbols
        let index = (weekday - 1) % 7
        return symbols.indices.contains(index) ? symbols[index] : ""
    }
}

/// In-process bridge: a tapped forecast notification posts this to open
/// the results screen with the pre-computed mood + goal selection.
enum ForecastLaunch {
    static let name = Notification.Name("moodE.forecastLaunch")
}
