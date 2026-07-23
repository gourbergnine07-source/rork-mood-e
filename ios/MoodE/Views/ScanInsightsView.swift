//
//  ScanInsightsView.swift
//  MoodE
//

import SwiftUI

/// One aggregated row from the `scan_missing_titles` RPC: a movie title the
/// poster scan recognized but TMDB doesn't have, with occurrence count.
nonisolated private struct MissingTitleRow: Decodable, Identifiable {
    let title: String
    let total: Int
    let lastSeen: String?

    var id: String { title }

    enum CodingKeys: String, CodingKey {
        case title, total
        case lastSeen = "last_seen"
    }
}

/// Internal dashboard (development builds only): aggregates the anonymous
/// `poster_scan_not_in_tmdb` events to show which movies users photograph
/// most often without finding them on TMDB. Data comes pre-aggregated from
/// a server-side function — raw events are never readable by the client.
struct ScanInsightsView: View {
    @State private var rows: [MissingTitleRow] = []
    @State private var isLoading = true
    @State private var hasError = false
    @State private var days: Int = 90

    private let periods: [(days: Int, key: String)] = [
        (30, "scan.dash.period.30"),
        (90, "scan.dash.period.90"),
        (365, "scan.dash.period.365")
    ]

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(L("scan.dash.subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)

                    Picker(L("scan.dash.title"), selection: $days) {
                        ForEach(periods, id: \.days) { period in
                            Text(L(period.key)).tag(period.days)
                        }
                    }
                    .pickerStyle(.segmented)

                    if isLoading {
                        loadingView
                    } else if hasError {
                        errorView
                    } else if rows.isEmpty {
                        emptyView
                    } else {
                        statsHeader
                        titlesList
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .refreshable { await load() }
        }
        .navigationTitle(L("scan.dash.title"))
        .toolbarTitleDisplayMode(.inline)
        .task { await load() }
        .onChange(of: days) { _, _ in
            Task { await load() }
        }
    }

    // MARK: - Sections

    private var statsHeader: some View {
        HStack(spacing: 10) {
            statCard(
                value: "\(rows.reduce(0) { $0 + $1.total })",
                label: L("scan.dash.total"),
                icon: "camera.viewfinder",
                tint: Theme.primary
            )
            statCard(
                value: "\(rows.count)",
                label: L("scan.dash.unique"),
                icon: "film.stack",
                tint: Theme.rose
            )
        }
    }

    private func statCard(value: String, label: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.card, in: .rect(cornerRadius: 16))
    }

    private var titlesList: some View {
        let maxTotal = rows.map(\.total).max() ?? 1
        return VStack(spacing: 10) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                titleRow(rank: index + 1, row: row, maxTotal: maxTotal)
            }
        }
    }

    private func titleRow(rank: Int, row: MissingTitleRow, maxTotal: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("#\(rank)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(rank <= 3 ? Theme.amber : Theme.inkSoft)
                    .frame(width: 30, alignment: .leading)
                Text(row.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                Spacer(minLength: 8)
                Text("\(row.total)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Theme.primary.opacity(0.12), in: .capsule)
            }

            // Proportional bar against the most-reported title.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.inkSoft.opacity(0.12))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Theme.primary, Theme.rose],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geo.size.width * CGFloat(row.total) / CGFloat(maxTotal)))
                }
            }
            .frame(height: 6)

            if let formatted = formattedDate(row.lastSeen) {
                Text(LF("scan.dash.lastseen", formatted))
                    .font(.caption2)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .padding(14)
        .background(Theme.card, in: .rect(cornerRadius: 16))
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.card)
                    .frame(height: 78)
            }
        }
        .redacted(reason: .placeholder)
        .padding(.top, 4)
    }

    private var emptyView: some View {
        VStack(spacing: 10) {
            Text("\u{1F50D}")
                .font(.system(size: 40))
                .padding(.top, 40)
            Text(L("scan.dash.empty.title"))
                .font(.headline)
                .foregroundStyle(Theme.ink)
            Text(L("scan.dash.empty.msg"))
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
    }

    private var errorView: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(Theme.inkSoft)
                .padding(.top, 40)
            Text(L("scan.dash.error"))
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
            Button(L("scan.dash.retry")) {
                Task { await load() }
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.bordered)
            .tint(Theme.primary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Data

    /// Calls the aggregate-only RPC with the anonymous key: it returns
    /// title + count + last date, never raw events or anon ids.
    private func load() async {
        if rows.isEmpty { isLoading = true }
        hasError = false
        defer { isLoading = false }

        guard let url = URL(string: Config.EXPO_PUBLIC_SUPABASE_URL + "/rest/v1/rpc/scan_missing_titles") else {
            hasError = true
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.EXPO_PUBLIC_SUPABASE_ANON_KEY, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(Config.EXPO_PUBLIC_SUPABASE_ANON_KEY)", forHTTPHeaderField: "Authorization")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: ["days": days])
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                print("ScanInsights: HTTP \(status)")
                hasError = true
                return
            }
            rows = try JSONDecoder().decode([MissingTitleRow].self, from: data)
        } catch {
            print("ScanInsights: load failed — \(error.localizedDescription)")
            hasError = true
        }
    }

    /// Formats the Postgres timestamptz (tolerates micro-second fractions
    /// that ISO8601DateFormatter can't always parse).
    private func formattedDate(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = iso.date(from: raw)
        if date == nil {
            iso.formatOptions = [.withInternetDateTime]
            var cleaned = raw
            if let dotIndex = raw.firstIndex(of: ".") {
                let tail = raw[raw.index(after: dotIndex)...]
                if let tzIndex = tail.firstIndex(where: { $0 == "+" || $0 == "Z" || $0 == "-" }) {
                    cleaned = String(raw[..<dotIndex]) + String(tail[tzIndex...])
                }
            }
            date = iso.date(from: cleaned)
        }
        guard let date else { return nil }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
