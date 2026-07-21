import WidgetKit
import SwiftUI

/// Snapshot written by the app in the App Group container (strings arrive
/// already localized). Mirrors `DiaryWidgetSnapshot` in the main app.
nonisolated struct WidgetSnapshot: Codable {
    let moodEmoji: String
    let moodTitle: String
    let headline: String
    let movieId: Int?
    let movieTitle: String?
    let posterPath: String?
    let updatedAt: Date
    /// Localized "How do you feel?" header for the interactive layout.
    var quickTitle: String?
    /// Most-used moods, tappable straight from the widget.
    var quickMoods: [WidgetQuickMoodItem]?
}

/// Compact mood option shared by the app (title pre-localized).
nonisolated struct WidgetQuickMoodItem: Codable {
    let raw: String
    let emoji: String
    let title: String
}

nonisolated enum WidgetStore {
    static let appGroupID = "group.app.rork.d9jknb2uwvfyntp4w88dj"
    static let snapshotKey = "widget.snapshot"

    static func load() -> WidgetSnapshot? {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}

nonisolated struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> MoodEntry {
        MoodEntry(date: .now, snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (MoodEntry) -> Void) {
        completion(MoodEntry(date: .now, snapshot: WidgetStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MoodEntry>) -> Void) {
        let entry = MoodEntry(date: .now, snapshot: WidgetStore.load())
        // Refresh once a day; the app also reloads it on every new check-in.
        let nextRefresh = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now)) ?? .now.addingTimeInterval(86_400)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

nonisolated struct MoodEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

/// Cinema-dark widget.
/// Small: latest mood + one matching movie pick (tap opens the movie).
/// Medium: interactive — the user taps one of their most-used moods and the
/// app opens straight on the results screen, skipping every step.
struct WidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: Provider.Entry

    private var deepLinkURL: URL? {
        guard let id = entry.snapshot?.movieId else { return nil }
        return URL(string: "moode://movie/\(id)")
    }

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                content(snapshot)
            } else {
                emptyState
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    Color(red: 0.09, green: 0.12, blue: 0.20),
                    Color(red: 0.13, green: 0.10, blue: 0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .widgetURL(family == .systemSmall ? deepLinkURL : nil)
    }

    @ViewBuilder
    private func content(_ snapshot: WidgetSnapshot) -> some View {
        switch family {
        case .systemMedium:
            if let moods = snapshot.quickMoods, !moods.isEmpty {
                interactiveMediumLayout(snapshot, moods: Array(moods.prefix(6)))
            } else {
                mediumLayout(snapshot)
            }
        default:
            smallLayout(snapshot)
        }
    }

    private func smallLayout(_ snapshot: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(snapshot.moodEmoji)
                .font(.system(size: 30))
            Text(snapshot.moodTitle)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer(minLength: 2)

            if let title = snapshot.movieTitle {
                Text(snapshot.headline)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color(red: 0.96, green: 0.75, blue: 0.44))
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Interactive medium (tap a mood → results in the app)

    private func interactiveMediumLayout(_ snapshot: WidgetSnapshot, moods: [WidgetQuickMoodItem]) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(snapshot.quickTitle ?? "Mood-E")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                HStack(spacing: 3) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9, weight: .semibold))
                    Text("Mood-E")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(.white.opacity(0.5))
            }

            HStack(spacing: 7) {
                ForEach(moods, id: \.raw) { mood in
                    moodTile(mood)
                }
            }

            if let title = snapshot.movieTitle {
                movieRow(snapshot, title: title)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// One tappable emotion: opens the app straight on the results screen.
    @ViewBuilder
    private func moodTile(_ mood: WidgetQuickMoodItem) -> some View {
        if let url = URL(string: "moode://flow/\(mood.raw)") {
            Link(destination: url) {
                VStack(spacing: 3) {
                    Text(mood.emoji)
                        .font(.system(size: 22))
                    Text(mood.title)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(.white.opacity(0.09), in: .rect(cornerRadius: 12))
            }
        }
    }

    /// Latest pick footer, tappable to reopen that movie.
    @ViewBuilder
    private func movieRow(_ snapshot: WidgetSnapshot, title: String) -> some View {
        let row = HStack(spacing: 6) {
            Text(snapshot.moodEmoji)
                .font(.system(size: 13))
            Text(snapshot.headline)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color(red: 0.96, green: 0.75, blue: 0.44))
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white.opacity(0.4))
        }

        if let url = deepLinkURL {
            Link(destination: url) { row }
        } else {
            row
        }
    }

    // MARK: - Legacy medium (no quick moods yet)

    private func mediumLayout(_ snapshot: WidgetSnapshot) -> some View {
        HStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(snapshot.moodEmoji)
                    .font(.system(size: 40))
                Text(snapshot.moodTitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .frame(width: 84)

            RoundedRectangle(cornerRadius: 2)
                .fill(.white.opacity(0.15))
                .frame(width: 2)
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.headline)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(red: 0.96, green: 0.75, blue: 0.44))
                if let title = snapshot.movieTitle {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }
                HStack(spacing: 4) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 11))
                    Text("Mood-E")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(.white.opacity(0.55))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("🎬")
                .font(.system(size: 30))
            Text("Mood-E")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MoodEWidget: Widget {
    let kind: String = "MoodEWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WidgetView(entry: entry)
        }
        .configurationDisplayName("Mood-E")
        .description("Tap how you feel and get a movie instantly.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
