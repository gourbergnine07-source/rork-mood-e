//
//  FriendsView.swift
//  MoodE
//

import SwiftUI

/// "Sfida gli amici": friend-code exchange plus head-to-head comparison
/// of the aggregate cinema statistics with each linked friend.
struct FriendsView: View {
    /// Friend code arriving from an invite deep link, pre-filled in the
    /// "add friend" field.
    var prefillCode: String? = nil

    @Environment(AuthManager.self) private var auth
    @Environment(MoodDiary.self) private var diary
    @Environment(MovieLibrary.self) private var library
    @Environment(MoviePlanner.self) private var planner
    @Environment(MovieStatsStore.self) private var statsStore

    private let service = FriendStatsService.shared

    @State private var codeInput: String = ""
    @State private var addFeedback: AddFeedback?
    @State private var isAdding: Bool = false
    @State private var didCopy: Bool = false
    @State private var compareTarget: FriendStatsRow?
    @State private var showAccountSheet: Bool = false

    private enum AddFeedback: Equatable {
        case success(String)
        case failure(String)
    }

    /// Local aggregate snapshot pushed to the cloud and used as "me"
    /// in every comparison.
    private var mySnapshot: FriendStatsRow {
        let stats = statsStore.stats(
            watched: library.watched,
            memories: planner.memories,
            checkIns: diary.checkIns,
            lifetimeWatched: library.lifetimeWatchedCount
        )
        return FriendStatsRow(
            userId: auth.user?.id ?? "",
            displayName: myDisplayName,
            friendCode: service.myCode,
            watchedCount: stats.watchedCount,
            totalMinutes: stats.totalMinutes,
            topGenreId: stats.topGenreId,
            topDecade: stats.topDecade,
            streak: diary.streak,
            bestStreak: diary.bestStreak
        )
    }

    private var myDisplayName: String {
        if let name = auth.user?.name, !name.isEmpty { return name }
        if let email = auth.user?.email, let prefix = email.split(separator: "@").first {
            return String(prefix)
        }
        return "Cinefilo"
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if auth.user == nil {
                        signInCard
                    } else {
                        myCodeCard
                        addFriendCard
                        friendsSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(L("friends.title"))
        .toolbarTitleDisplayMode(.inline)
        .task {
            if let prefillCode, codeInput.isEmpty {
                codeInput = String(prefillCode.uppercased().prefix(12))
            }
            await refresh()
        }
        .onChange(of: auth.user?.id) { _, newValue in
            if newValue != nil {
                Task { await refresh() }
            }
        }
        .sheet(isPresented: $showAccountSheet) {
            AccountSheetView()
        }
        .sheet(item: $compareTarget) { friend in
            FriendCompareSheet(me: mySnapshot, friend: friend)
        }
        .sensoryFeedback(.success, trigger: didCopy)
    }

    private func refresh() async {
        guard auth.user != nil else { return }
        await statsStore.refresh(watched: library.watched, memories: planner.memories)
        await service.refresh(auth: auth, snapshot: mySnapshot)
    }

    // MARK: - Signed out

    private var signInCard: some View {
        VStack(spacing: 14) {
            Text("🏆")
                .font(.system(size: 52))

            Text(L("friends.signin.title"))
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)

            Text(L("friends.signin.msg"))
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            Button {
                showAccountSheet = true
            } label: {
                Text(L("friends.signin.button"))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Theme.primary, in: .rect(cornerRadius: 14))
                    .contentShape(.rect)
            }
            .buttonStyle(PressableCardStyle())
            .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Theme.card, in: .rect(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Theme.primary.opacity(0.20), lineWidth: 1)
        )
    }

    // MARK: - My code

    private var myCodeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("friends.mycode.title"))
                .font(.headline)
                .foregroundStyle(Theme.ink)

            HStack(spacing: 10) {
                Text(service.myCode ?? "········")
                    .font(.system(size: 26, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.primary)
                    .kerning(2)
                    .redacted(reason: service.myCode == nil ? .placeholder : [])

                Spacer()

                Button {
                    guard let code = service.myCode else { return }
                    UIPasteboard.general.string = code
                    didCopy.toggle()
                } label: {
                    Label(L("friends.mycode.copy"), systemImage: "doc.on.doc")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Theme.primary.opacity(0.12), in: .capsule)
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .disabled(service.myCode == nil)

                if let code = service.myCode {
                    ShareLink(item: InviteLink.shareMessage(code: code)) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.primary)
                            .frame(width: 32, height: 32)
                            .background(Theme.primary.opacity(0.12), in: .circle)
                            .contentShape(.circle)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(L("friends.mycode.sub"))
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
        }
        .padding(16)
        .background(Theme.card, in: .rect(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.primary.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Add friend

    private var addFriendCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("friends.add.title"))
                .font(.headline)
                .foregroundStyle(Theme.ink)

            HStack(spacing: 10) {
                TextField(L("friends.add.placeholder"), text: $codeInput)
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(Theme.surface.opacity(0.7), in: .rect(cornerRadius: 12))
                    .onChange(of: codeInput) { _, newValue in
                        codeInput = String(newValue.uppercased().prefix(12))
                        if addFeedback != nil { addFeedback = nil }
                    }

                Button {
                    Task { await addFriend() }
                } label: {
                    Group {
                        if isAdding {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(L("friends.add.button"))
                                .font(.subheadline.weight(.bold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(width: 92, height: 44)
                    .background(
                        codeInput.trimmingCharacters(in: .whitespaces).isEmpty
                            ? AnyShapeStyle(Theme.inkSoft.opacity(0.4))
                            : AnyShapeStyle(Theme.primary),
                        in: .rect(cornerRadius: 12)
                    )
                    .contentShape(.rect)
                }
                .buttonStyle(PressableCardStyle())
                .disabled(codeInput.trimmingCharacters(in: .whitespaces).isEmpty || isAdding)
            }

            if let addFeedback {
                switch addFeedback {
                case .success(let message):
                    Label(message, systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.seenGreen)
                case .failure(let message):
                    Label(message, systemImage: "exclamationmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.rose)
                }
            }
        }
        .padding(16)
        .background(Theme.card, in: .rect(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.primary.opacity(0.08), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: addFeedback)
    }

    private func addFriend() async {
        let code = codeInput.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty else { return }
        isAdding = true
        defer { isAdding = false }

        do {
            let name = try await service.addFriend(code: code, auth: auth)
            codeInput = ""
            addFeedback = .success(LF("friends.add.success", name))
            await service.refresh(auth: auth, snapshot: mySnapshot)
        } catch FriendAddError.codeNotFound {
            addFeedback = .failure(L("friends.add.notFound"))
        } catch FriendAddError.ownCode {
            addFeedback = .failure(L("friends.add.own"))
        } catch {
            addFeedback = .failure(L("friends.add.error"))
        }
    }

    // MARK: - Friends list

    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("friends.list.title"))
                .font(.headline)
                .foregroundStyle(Theme.ink)

            if service.isLoading && service.friends.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding(.vertical, 20)
                    Spacer()
                }
            } else if service.friends.isEmpty {
                VStack(spacing: 8) {
                    Text("👋")
                        .font(.system(size: 34))
                    Text(L("friends.list.empty"))
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Theme.card.opacity(0.6), in: .rect(cornerRadius: 20))
            } else {
                ForEach(service.friends) { friend in
                    friendRow(friend)
                }
            }
        }
        .padding(.top, 4)
    }

    private func friendRow(_ friend: FriendStatsRow) -> some View {
        Button {
            compareTarget = friend
        } label: {
            HStack(spacing: 12) {
                Text(String(friend.displayName.prefix(1)).uppercased())
                    .font(.headline.weight(.black))
                    .foregroundStyle(Theme.primary)
                    .frame(width: 40, height: 40)
                    .background(Theme.primary.opacity(0.14), in: .circle)

                VStack(alignment: .leading, spacing: 2) {
                    Text(friend.displayName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text(LF("friends.list.films", friend.watchedCount))
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                        .monospacedDigit()
                }

                Spacer()

                Text(L("friends.compare.vs"))
                    .font(.caption.weight(.black))
                    .foregroundStyle(Theme.amber)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.amber.opacity(0.14), in: .capsule)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
            .padding(14)
            .background(Theme.card, in: .rect(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Theme.primary.opacity(0.08), lineWidth: 1)
            )
            .contentShape(.rect)
        }
        .buttonStyle(PressableCardStyle())
        .contextMenu {
            Button(role: .destructive) {
                Task { await service.removeFriend(userId: friend.userId, auth: auth) }
            } label: {
                Label(L("friends.remove"), systemImage: "person.badge.minus")
            }
        }
    }
}

/// Head-to-head sheet: my snapshot vs one friend, metric by metric.
private struct FriendCompareSheet: View {
    let me: FriendStatsRow
    let friend: FriendStatsRow

    @Environment(\.dismiss) private var dismiss

    /// Positive = I lead, negative = the friend leads.
    private var score: Int {
        var total = 0
        for (mine, theirs) in [
            (me.watchedCount, friend.watchedCount),
            (me.totalMinutes, friend.totalMinutes),
            (me.streak, friend.streak),
            (me.bestStreak, friend.bestStreak)
        ] {
            if mine > theirs { total += 1 }
            if theirs > mine { total -= 1 }
        }
        return total
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        header

                        VStack(spacing: 12) {
                            CompareBarRow(
                                label: L("friends.compare.films"),
                                emoji: "🎬",
                                mine: me.watchedCount,
                                theirs: friend.watchedCount,
                                format: { "\($0)" }
                            )
                            CompareBarRow(
                                label: L("friends.compare.hours"),
                                emoji: "⏱️",
                                mine: me.totalMinutes,
                                theirs: friend.totalMinutes,
                                format: { Self.hoursText($0) }
                            )
                            CompareBarRow(
                                label: L("friends.compare.streak"),
                                emoji: "🔥",
                                mine: me.streak,
                                theirs: friend.streak,
                                format: { "\($0)" }
                            )
                            CompareBarRow(
                                label: L("friends.compare.best"),
                                emoji: "🏅",
                                mine: me.bestStreak,
                                theirs: friend.bestStreak,
                                format: { "\($0)" }
                            )
                        }

                        tasteCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(L("friends.compare.title"))
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    .accessibilityLabel(L("common.close"))
                }
            }
        }
        .presentationDetents([.large])
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                nameBubble(L("friends.compare.you"), tint: Theme.primary)
                Text(L("friends.compare.vs"))
                    .font(.title3.weight(.black))
                    .foregroundStyle(Theme.amber)
                nameBubble(friend.displayName, tint: Theme.rose)
            }

            Text(verdictText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(score >= 0 ? Theme.seenGreen : Theme.amber)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Theme.card, in: .rect(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Theme.amber.opacity(0.25), lineWidth: 1)
        )
    }

    private var verdictText: String {
        if score > 0 { return L("friends.compare.win") }
        if score < 0 { return LF("friends.compare.lose", friend.displayName) }
        return L("friends.compare.tie")
    }

    private func nameBubble(_ name: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Text(String(name.prefix(1)).uppercased())
                .font(.title3.weight(.black))
                .foregroundStyle(tint)
                .frame(width: 48, height: 48)
                .background(tint.opacity(0.14), in: .circle)
            Text(name)
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
        }
        .frame(maxWidth: 110)
    }

    /// Favorite genre and top decade, side by side (no winner here —
    /// taste is taste).
    private var tasteCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            compareTextRow(
                emoji: "🎭",
                label: L("friends.compare.genre"),
                mine: me.topGenreId.flatMap { TMDBGenreCatalog.name(for: $0) } ?? "—",
                theirs: friend.topGenreId.flatMap { TMDBGenreCatalog.name(for: $0) } ?? "—"
            )
            Divider()
            compareTextRow(
                emoji: "🕰️",
                label: L("friends.compare.decade"),
                mine: me.topDecade.map { LF("stats.decade.label", $0) } ?? "—",
                theirs: friend.topDecade.map { LF("stats.decade.label", $0) } ?? "—"
            )
        }
        .padding(16)
        .background(Theme.card, in: .rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Theme.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func compareTextRow(emoji: String, label: String, mine: String, theirs: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(emoji) \(label)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.inkSoft)
            HStack {
                Text(mine)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Theme.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(theirs)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Theme.rose)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    static func hoursText(_ minutes: Int) -> String {
        guard minutes > 0 else { return "0h" }
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
        return "\(mins)min"
    }
}

/// One metric with two proportional bars (me above, friend below);
/// the leader's bar gets the strong color.
private struct CompareBarRow: View {
    let label: String
    let emoji: String
    let mine: Int
    let theirs: Int
    let format: (Int) -> String

    private var maxValue: Double {
        Double(max(mine, theirs, 1))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(emoji) \(label)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.inkSoft)

            bar(value: mine, tint: Theme.primary, leads: mine >= theirs)
            bar(value: theirs, tint: Theme.rose, leads: theirs >= mine)
        }
        .padding(14)
        .background(Theme.card, in: .rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Theme.primary.opacity(0.08), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(format(mine)) — \(format(theirs))")
    }

    private func bar(value: Int, tint: Color, leads: Bool) -> some View {
        HStack(spacing: 8) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.surface.opacity(0.7))
                    Capsule()
                        .fill(tint.opacity(leads ? 1 : 0.45))
                        .frame(width: max(10, proxy.size.width * CGFloat(Double(value) / maxValue)))
                        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: value)
                }
            }
            .frame(height: 10)

            Text(format(value))
                .font(.caption.weight(.bold))
                .foregroundStyle(leads ? tint : Theme.inkSoft)
                .monospacedDigit()
                .frame(width: 64, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

#Preview {
    NavigationStack {
        FriendsView()
    }
    .environment(AuthManager())
    .environment(MoodDiary())
    .environment(MovieLibrary())
    .environment(MoviePlanner())
    .environment(MovieStatsStore())
}
