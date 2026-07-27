//
//  ChallengeDuoView.swift
//  MoodE
//

import SwiftUI

/// "Sfida un amico" (Premium): run the monthly challenge together via a
/// shareable 6-digit code — same anonymous logic as the duo night. Only the
/// two progress counters travel to the cloud; no names, no accounts, no
/// public leaderboard.
struct ChallengeDuoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(MoodDiary.self) private var diary
    @Environment(MovieLibrary.self) private var library
    @Environment(MoviePlanner.self) private var planner

    /// Local pairing, persisted so the comparison survives app restarts.
    @AppStorage("chduo.code") private var pairedCode: String = ""
    @AppStorage("chduo.role") private var pairedRoleRaw: String = ""
    @AppStorage("chduo.month") private var pairedMonth: String = ""

    @State private var row: ChallengeDuoRow?
    @State private var joinCode: String = ""
    @State private var isWorking: Bool = false
    @State private var errorText: String?

    private var challenge: MonthlyChallenge { ChallengeCalendar.current() }
    private var isPaired: Bool { !pairedCode.isEmpty && pairedMonth == challenge.id }
    private var role: DuoRole { pairedRoleRaw == "guest" ? .guest : .host }

    private var myProgress: ChallengeProgress {
        challenge.progress(diary: diary, library: library, planner: planner)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header

                        if isPaired {
                            pairedSection
                        } else {
                            landingSection
                        }

                        Text(L("chduo.privacy"))
                            .font(.caption2)
                            .foregroundStyle(Theme.inkSoft.opacity(0.85))
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(L("chduo.title"))
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.close")) { dismiss() }
                }
            }
            .task(id: isPaired) {
                guard isPaired else { return }
                while !Task.isCancelled {
                    await refresh()
                    try? await Task.sleep(for: .seconds(4))
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Text(challenge.emoji)
                .font(.system(size: 34))
            VStack(alignment: .leading, spacing: 2) {
                Text(challenge.title)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text(challenge.detail)
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: .rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Theme.amber.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Landing (create / join)

    private var landingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L("chduo.sub"))
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)

            Button {
                Task { await createPairing() }
            } label: {
                HStack(spacing: 8) {
                    if isWorking {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    Text(L("chduo.create"))
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Theme.amber, in: .rect(cornerRadius: 14))
            }
            .disabled(isWorking)

            HStack(spacing: 8) {
                TextField(L("chduo.code.placeholder"), text: $joinCode)
                    .keyboardType(.numberPad)
                    .font(.body.monospacedDigit())
                    .padding(.horizontal, 14)
                    .frame(height: 46)
                    .background(Theme.card, in: .rect(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Theme.inkSoft.opacity(0.2), lineWidth: 1)
                    )

                Button {
                    Task { await joinPairing() }
                } label: {
                    Text(L("chduo.join"))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .frame(height: 46)
                        .background(
                            joinCode.count == 6 ? Theme.tabList : Theme.tabList.opacity(0.4),
                            in: .rect(cornerRadius: 14)
                        )
                }
                .disabled(joinCode.count != 6 || isWorking)
            }

            if let errorText {
                Label(errorText, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.rose)
            }
        }
    }

    // MARK: - Paired (comparison)

    private var pairedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Code + share
            HStack(spacing: 10) {
                Text(pairedCode)
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.ink)
                    .kerning(3)

                Spacer()

                ShareLink(item: LF("chduo.share.text", pairedCode)) {
                    Label(L("chduo.share"), systemImage: "square.and.arrow.up")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.amber)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(Theme.amber.opacity(0.12), in: .capsule)
                }
            }
            .padding(14)
            .background(Theme.card, in: .rect(cornerRadius: 16))

            if role == .host, row?.guestJoined != true {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(L("chduo.waiting"))
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
            }

            // Comparison
            VStack(alignment: .leading, spacing: 12) {
                Text(L("chduo.progress"))
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Theme.ink)

                progressRow(
                    label: L("chduo.you"),
                    value: myProgress.value,
                    target: challenge.kind.target,
                    tint: Theme.primary
                )
                progressRow(
                    label: L("chduo.friend"),
                    value: friendValue,
                    target: challenge.kind.target,
                    tint: Theme.rose
                )

                if bothDone {
                    Text(L("chduo.both.done"))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.seenGreen)
                }
            }
            .padding(14)
            .background(Theme.card, in: .rect(cornerRadius: 16))

            Button(role: .destructive) {
                leavePairing()
            } label: {
                Text(L("chduo.leave"))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.rose)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Theme.rose.opacity(0.1), in: .rect(cornerRadius: 12))
            }
        }
    }

    private func progressRow(label: String, value: Int, target: Int, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(min(value, target))/\(target)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.surface)
                    Capsule()
                        .fill(tint)
                        .frame(width: max(geo.size.width * fraction(value, target), value > 0 ? 8 : 0))
                }
            }
            .frame(height: 7)
            .animation(.spring(response: 0.6, dampingFraction: 0.85), value: value)
        }
    }

    private func fraction(_ value: Int, _ target: Int) -> Double {
        min(Double(value) / Double(max(target, 1)), 1)
    }

    private var friendValue: Int {
        guard let row else { return 0 }
        return role == .host ? row.guestProgress : row.hostProgress
    }

    private var bothDone: Bool {
        myProgress.isComplete && friendValue >= challenge.kind.target
    }

    // MARK: - Actions

    private func createPairing() async {
        guard !isWorking else { return }
        isWorking = true
        errorText = nil
        do {
            let code = try await ChallengeDuoService.create(monthKey: challenge.id)
            pairedCode = code
            pairedRoleRaw = "host"
            pairedMonth = challenge.id
            AnalyticsService.shared.log("challenge_duo_created")
            // Challenge codes also link the two people as "amici" for the
            // friends-only Stato Mood visibility.
            StatusService.shared.registerFriendCode(code)
            await refresh()
        } catch {
            errorText = L("chduo.error.generic")
        }
        isWorking = false
    }

    private func joinPairing() async {
        guard !isWorking else { return }
        isWorking = true
        errorText = nil
        do {
            let joined = try await ChallengeDuoService.join(code: joinCode, monthKey: challenge.id)
            pairedCode = joined.code
            pairedRoleRaw = "guest"
            pairedMonth = challenge.id
            AnalyticsService.shared.log("challenge_duo_joined")
            // Joining links the two people as "amici" for Stato Mood.
            StatusService.shared.registerFriendCode(joined.code)
            await refresh()
        } catch DuoError.notFound {
            errorText = L("chduo.error.notfound")
        } catch {
            errorText = L("chduo.error.generic")
        }
        isWorking = false
    }

    /// Publishes my local progress, then pulls the friend's counter.
    private func refresh() async {
        guard isPaired else { return }
        try? await ChallengeDuoService.updateProgress(
            code: pairedCode,
            role: role,
            value: myProgress.value
        )
        do {
            row = try await ChallengeDuoService.fetch(code: pairedCode)
        } catch {
            // Expired or deleted pairing: keep the last snapshot on screen.
        }
    }

    private func leavePairing() {
        pairedCode = ""
        pairedRoleRaw = ""
        pairedMonth = ""
        row = nil
    }
}
