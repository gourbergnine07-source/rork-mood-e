//
//  MyStatsView.swift
//  MoodE
//

import SwiftUI

/// "Le mie statistiche": aggregate lifetime cinema numbers and genre
/// milestones, complementary to the per-movie "I miei ricordi" gallery.
struct MyStatsView: View {
    @Environment(MoodDiary.self) private var diary
    @Environment(MovieLibrary.self) private var library
    @Environment(MoviePlanner.self) private var planner
    @Environment(MovieStatsStore.self) private var statsStore

    @State private var sharePayload: ShareCardPayload?
    @State private var didShare: Bool = false

    /// Watched movies needed before the dashboard unlocks.
    private static let unlockThreshold = 5

    /// Main TMDB genres shown in the "Collezioni" grid.
    private static let collectionGenres: [Int] = [18, 35, 28, 27, 16, 878, 10749, 99]

    /// Genre milestones reusing the existing badge system.
    private static let genreBadges: [Int: Badge] = [
        27: .esploratoreHorror,
        18: .amanteDelDramma,
        35: .reDellaCommedia,
        16: .animatore,
        99: .documentarista
    ]

    private var cineStats: CineStats {
        statsStore.stats(
            watched: library.watched,
            memories: planner.memories,
            checkIns: diary.checkIns,
            lifetimeWatched: library.lifetimeWatchedCount
        )
    }

    var body: some View {
        let stats = cineStats

        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if stats.watchedCount < Self.unlockThreshold {
                        lockedCard(watched: stats.watchedCount)
                    } else {
                        dashboard(stats)
                        collectionsSection(stats)
                        shareButton(stats)
                    }

                    friendsLink

                    memoriesLink
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(L("stats.title"))
        .toolbarTitleDisplayMode(.inline)
        .task {
            await statsStore.refresh(watched: library.watched, memories: planner.memories)
        }
        .sheet(item: $sharePayload) { payload in
            ShareCardSheet(payload: payload)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: didShare)
    }

    // MARK: - Locked state

    private func lockedCard(watched: Int) -> some View {
        VStack(spacing: 14) {
            Text("📊")
                .font(.system(size: 52))

            Text(L("stats.locked.title"))
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.ink)

            Text(L("stats.locked.msg"))
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            VStack(spacing: 6) {
                ProgressView(value: Double(watched), total: Double(Self.unlockThreshold))
                    .tint(Theme.amber)

                Text(LF("stats.locked.progress", watched, Self.unlockThreshold))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.amber)
                    .monospacedDigit()
            }
            .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Theme.card, in: .rect(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Theme.amber.opacity(0.30), lineWidth: 1)
        )
    }

    // MARK: - Dashboard

    private func dashboard(_ stats: CineStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            heroCard(stats)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                StatTile(
                    emoji: "🎭",
                    label: L("stats.card.topGenre"),
                    value: topGenreText(stats) ?? "—"
                )
                StatTile(
                    emoji: stats.topMood?.emoji ?? "🙂",
                    label: L("stats.card.topMood"),
                    value: stats.topMood?.title ?? "—"
                )
                StatTile(
                    emoji: "🕰️",
                    label: L("stats.card.decade"),
                    value: stats.topDecade.map { LF("stats.decade.label", $0) } ?? "—"
                )
                StatTile(
                    emoji: stats.bestMemory?.ratingEmoji ?? "🏆",
                    label: L("stats.card.best"),
                    value: stats.bestMemory?.title ?? "—"
                )
            }
        }
    }

    /// Big headline card: total movies + estimated hours.
    private func heroCard(_ stats: CineStats) -> some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("\(stats.watchedCount)")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.primary)
                    .contentTransition(.numericText())
                Text(L("stats.card.films"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(Theme.inkSoft.opacity(0.15))
                .frame(width: 1, height: 52)

            VStack(spacing: 4) {
                Text(hoursText(stats.totalMinutes))
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.amber)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(L("stats.card.hours"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 12)
        .background(Theme.card, in: .rect(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Theme.primary.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Collections

    private func collectionsSection(_ stats: CineStats) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L("stats.collections.title"))
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text(L("stats.collections.subtitle"))
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            }

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                ForEach(Self.collectionGenres, id: \.self) { genreId in
                    GenreCollectionCard(
                        genreId: genreId,
                        count: stats.genreCounts[genreId, default: 0],
                        badge: Self.genreBadges[genreId]
                    )
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Share

    private func shareButton(_ stats: CineStats) -> some View {
        Button {
            share(stats)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                Text(L("stats.share"))
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Theme.primary, in: .rect(cornerRadius: 15))
            .contentShape(.rect)
        }
        .buttonStyle(PressableCardStyle())
    }

    private func share(_ stats: CineStats) {
        let card = StatsShareCardView(
            films: stats.watchedCount,
            hoursText: hoursText(stats.totalMinutes),
            genreText: topGenreText(stats),
            moodText: stats.topMood.map { "\($0.emoji) \($0.title)" },
            decadeText: stats.topDecade.map { LF("stats.decade.label", $0) },
            favoriteText: stats.bestMemory.map { "\($0.title) \($0.ratingEmoji)" }
        )
        guard let image = ShareCardRenderer.render(card) else { return }
        didShare.toggle()
        sharePayload = ShareCardPayload(image: image, title: L("stats.share.cardTitle"))
    }

    // MARK: - Friends quick link

    /// Entry point to the friends comparison: exchange friend codes and
    /// see who is ahead, metric by metric.
    private var friendsLink: some View {
        NavigationLink(value: DiaryRoute.friends) {
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
                    .stroke(Theme.amber.opacity(0.30), lineWidth: 1)
            )
        }
        .buttonStyle(PressableCardStyle())
    }

    // MARK: - Memories quick link

    /// Quick jump to the per-movie gallery: this screen stays about numbers,
    /// "I miei ricordi" is where individual movies and comments live.
    private var memoriesLink: some View {
        NavigationLink(value: DiaryRoute.memories) {
            HStack(spacing: 12) {
                Text("🎞️")
                    .font(.system(size: 26))
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("memories.row.title"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text(L("stats.memories.subtitle"))
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
        .buttonStyle(PressableCardStyle())
    }

    // MARK: - Helpers

    private func topGenreText(_ stats: CineStats) -> String? {
        guard let genreId = stats.topGenreId,
              let name = TMDBGenreCatalog.name(for: genreId) else { return nil }
        return stats.topGenreShare > 0 ? "\(name) · \(stats.topGenreShare)%" : name
    }

    /// "≈ 12h 45min" from total minutes (estimate from TMDB runtimes).
    private func hoursText(_ minutes: Int) -> String {
        guard minutes > 0 else { return "—" }
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return mins > 0 ? "≈ \(hours)h \(mins)min" : "≈ \(hours)h"
        }
        return "≈ \(mins)min"
    }
}

/// Small dashboard tile: emoji, value and caption label.
private struct StatTile: View {
    let emoji: String
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(emoji)
                .font(.system(size: 24))
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.inkSoft)
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .background(Theme.card, in: .rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Theme.primary.opacity(0.08), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

/// Genre collection card: watched count plus the genre milestone progress
/// when that genre has an associated badge.
private struct GenreCollectionCard: View {
    let genreId: Int
    let count: Int
    let badge: Badge?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(genreEmoji)
                    .font(.system(size: 22))
                VStack(alignment: .leading, spacing: 0) {
                    Text(TMDBGenreCatalog.name(for: genreId) ?? "—")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text(LF("stats.collections.count", count))
                        .font(.caption2)
                        .foregroundStyle(Theme.inkSoft)
                        .monospacedDigit()
                }
                Spacer(minLength: 0)
            }

            if let badge, let goal = badge.genreGoal {
                if count >= goal.target {
                    Label("\(badge.emoji) \(badge.title)", systemImage: "checkmark.seal.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.seenGreen)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                } else {
                    VStack(alignment: .leading, spacing: 3) {
                        ProgressView(value: Double(min(count, goal.target)), total: Double(goal.target))
                            .tint(Theme.amber)
                            .scaleEffect(y: 0.7)
                        Text("\(badge.emoji) \(badge.title) · \(count)/\(goal.target)")
                            .font(.caption2)
                            .foregroundStyle(Theme.inkSoft)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
        .background(Theme.card, in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    (badge != nil && count >= (badge?.genreGoal?.target ?? .max))
                        ? Theme.amber.opacity(0.4)
                        : Theme.primary.opacity(0.08),
                    lineWidth: 1
                )
        )
        .accessibilityElement(children: .combine)
    }

    private var genreEmoji: String {
        switch genreId {
        case 18: return "🎭"
        case 35: return "😂"
        case 28: return "💥"
        case 27: return "👻"
        case 16: return "🎨"
        case 878: return "🚀"
        case 10749: return "💘"
        case 99: return "🎥"
        default: return "🎬"
        }
    }
}

#Preview {
    NavigationStack {
        MyStatsView()
    }
    .environment(MoodDiary())
    .environment(MovieLibrary())
    .environment(MoviePlanner())
    .environment(MovieStatsStore())
}
