//
//  MoviePlanner.swift
//  MoodE
//

import Foundation
import Observation

/// Wrapped-style summary of a month with enough watched movies.
struct MonthlyRecap {
    let watchedCount: Int
    let topMood: Mood?
    let topGenreName: String?
    let favorite: MovieMemory?
}

/// Local, account-free movie planning: one movie can be scheduled per
/// calendar day, and once watched it becomes a personal `MovieMemory`.
/// Everything is persisted as JSON in UserDefaults, like the mood diary.
@Observable
final class MoviePlanner {
    private(set) var scheduled: [ScheduledMovie]
    private(set) var memories: [MovieMemory]

    private static let scheduledKey = "planner.scheduled"
    private static let memoriesKey = "planner.memories"
    /// Minimum watched movies in a month to unlock the monthly recap.
    private static let monthlyRecapThreshold = 8

    private let defaults = UserDefaults.standard

    init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Self.scheduledKey),
           let stored = try? JSONDecoder().decode([ScheduledMovie].self, from: data) {
            scheduled = stored
        } else {
            scheduled = []
        }
        if let data = defaults.data(forKey: Self.memoriesKey),
           let stored = try? JSONDecoder().decode([MovieMemory].self, from: data) {
            memories = stored
        } else {
            memories = []
        }
    }

    // MARK: - Queries

    /// The movie planned on a given day (at most one per day).
    func scheduledMovie(on day: Date) -> ScheduledMovie? {
        let calendar = Calendar.current
        return scheduled.first { calendar.isDate($0.day, inSameDayAs: day) }
    }

    func hasScheduled(on day: Date) -> Bool {
        scheduledMovie(on: day) != nil
    }

    /// Plans whose day is already past and were never marked as watched,
    /// oldest first — they still need an outcome (watched or removed).
    var pendingPastScheduled: [ScheduledMovie] {
        let today = Calendar.current.startOfDay(for: Date())
        return scheduled
            .filter { $0.day < today }
            .sorted { $0.day < $1.day }
    }

    /// True when the movie planned on `day` is in the past and still
    /// waiting to be marked as watched.
    func hasPendingSchedule(on day: Date) -> Bool {
        guard let plan = scheduledMovie(on: day) else { return false }
        return plan.day < Calendar.current.startOfDay(for: Date())
    }

    /// Memories newest first, for "I miei ricordi cinematografici".
    var sortedMemories: [MovieMemory] {
        memories.sorted { $0.watchedDate > $1.watchedDate }
    }

    // MARK: - Scheduling

    /// Plans a movie on a day, replacing any previous plan for that day.
    /// Saving is instant: no separate confirm step.
    func schedule(movieId: Int, title: String, posterPath: String?, genreIds: [Int]?, on day: Date) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        scheduled.removeAll { calendar.isDate($0.day, inSameDayAs: start) }
        scheduled.append(
            ScheduledMovie(
                id: UUID(),
                movieId: movieId,
                title: title,
                posterPath: posterPath,
                genreIds: genreIds,
                day: start
            )
        )
        persistScheduled()
    }

    /// Moves an existing plan to a new day (replacing any plan already there).
    func move(_ id: UUID, to day: Date) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        scheduled.removeAll { $0.id != id && calendar.isDate($0.day, inSameDayAs: start) }
        guard let index = scheduled.firstIndex(where: { $0.id == id }) else { return }
        scheduled[index].day = start
        persistScheduled()
    }

    /// Removes a plan; the movie stays in the general watchlist if present.
    func removeSchedule(_ id: UUID) {
        let before = scheduled.count
        scheduled.removeAll { $0.id == id }
        if scheduled.count != before { persistScheduled() }
    }

    // MARK: - Memories

    /// Turns a planned movie into a memory with emoji rating and optional
    /// comment. The memory date is the planned day when it's in the past,
    /// otherwise now.
    @discardableResult
    func markWatched(_ id: UUID, rating: Int, comment: String?) -> MovieMemory? {
        guard let index = scheduled.firstIndex(where: { $0.id == id }) else { return nil }
        let plan = scheduled.remove(at: index)

        let calendar = Calendar.current
        let watchedDate = plan.day < calendar.startOfDay(for: Date()) ? plan.day : Date()

        let trimmed = comment?.trimmingCharacters(in: .whitespacesAndNewlines)
        let memory = MovieMemory(
            id: UUID(),
            movieId: plan.movieId,
            title: plan.title,
            posterPath: plan.posterPath,
            genreIds: plan.genreIds,
            watchedDate: watchedDate,
            rating: min(max(rating, EmojiRating.range.lowerBound), EmojiRating.range.upperBound),
            comment: (trimmed?.isEmpty ?? true) ? nil : trimmed
        )
        memories.insert(memory, at: 0)
        persistScheduled()
        persistMemories()
        return memory
    }

    /// Deletes a memory from the personal gallery.
    func removeMemory(_ id: UUID) {
        let before = memories.count
        memories.removeAll { $0.id == id }
        if memories.count != before { persistMemories() }
    }

    // MARK: - Monthly recap

    /// Wrapped-style recap for the month containing `month`, available once
    /// at least 8 movies were watched in that month. Top emotion comes from
    /// the diary check-ins of the same month.
    func monthlyRecap(for month: Date, checkIns: [MoodCheckIn]) -> MonthlyRecap? {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return nil }

        let monthMemories = memories.filter { interval.contains($0.watchedDate) }
        guard monthMemories.count >= Self.monthlyRecapThreshold else { return nil }

        var moodCounts: [String: Int] = [:]
        for checkIn in checkIns where interval.contains(checkIn.date) {
            moodCounts[checkIn.moodRaw, default: 0] += 1
        }
        let topMood = moodCounts
            .max { $0.value < $1.value }
            .flatMap { Mood(rawValue: $0.key) }

        var genreCounts: [Int: Int] = [:]
        for memory in monthMemories {
            for genre in memory.genreIds ?? [] {
                genreCounts[genre, default: 0] += 1
            }
        }
        let topGenreName = genreCounts
            .max { $0.value < $1.value }
            .flatMap { TMDBGenreCatalog.name(for: $0.key) }

        let favorite = monthMemories.max {
            ($0.rating, $0.watchedDate) < ($1.rating, $1.watchedDate)
        }

        return MonthlyRecap(
            watchedCount: monthMemories.count,
            topMood: topMood,
            topGenreName: topGenreName,
            favorite: favorite
        )
    }

    // MARK: - Persistence

    private func persistScheduled() {
        do {
            let data = try JSONEncoder().encode(scheduled)
            defaults.set(data, forKey: Self.scheduledKey)
        } catch {
            print("MoviePlanner: persist scheduled failed: \(error.localizedDescription)")
        }
        CloudSyncService.shared.noteLocalChange()
    }

    private func persistMemories() {
        do {
            let data = try JSONEncoder().encode(memories)
            defaults.set(data, forKey: Self.memoriesKey)
        } catch {
            print("MoviePlanner: persist memories failed: \(error.localizedDescription)")
        }
        CloudSyncService.shared.noteLocalChange()
    }

    /// Replaces plans and memories with the cloud-merged copy (sync only).
    func replaceAll(scheduled newScheduled: [ScheduledMovie], memories newMemories: [MovieMemory]) {
        scheduled = newScheduled.sorted { $0.day < $1.day }
        memories = newMemories.sorted { $0.watchedDate > $1.watchedDate }
        persistScheduled()
        persistMemories()
    }
}
