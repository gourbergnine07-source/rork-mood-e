//
//  ChallengeCard.swift
//  MoodE
//

import SwiftUI

/// "Sfida del mese": the active monthly challenge with an animated
/// progress bar computed from local data. On completion it unlocks the
/// "Sfidante" badge and plays a small celebration.
struct ChallengeCard: View {
    @Environment(MoodDiary.self) private var diary
    @Environment(MovieLibrary.self) private var library
    @Environment(MoviePlanner.self) private var planner

    @State private var store = ChallengeStore.shared
    @State private var celebrating: Bool = false
    @State private var animatedFraction: Double = 0
    @State private var showDuoChallenge: Bool = false
    @State private var showPaywall: Bool = false

    private var challenge: MonthlyChallenge { ChallengeCalendar.current() }

    var body: some View {
        let progress = challenge.progress(diary: diary, library: library, planner: planner)
        let isDone = store.isCompleted(challenge.id) || progress.isComplete

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(challenge.emoji)
                    .font(.system(size: 26))
                    .scaleEffect(celebrating ? 1.35 : 1)
                    .animation(.spring(response: 0.4, dampingFraction: 0.5), value: celebrating)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Image(systemName: "flag.checkered")
                            .font(.system(size: 10, weight: .semibold))
                        Text(L("challenge.header"))
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(Theme.rose)

                    Text(challenge.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.ink)
                }

                Spacer(minLength: 0)

                if isDone {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.seenGreen)
                        .symbolEffect(.bounce, value: celebrating)
                }
            }

            Text(challenge.detail)
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)

            // Progress bar + counter.
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Theme.surface)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: isDone
                                        ? [Theme.seenGreen, Theme.seenGreen.opacity(0.7)]
                                        : [Theme.rose, Theme.amber],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(geo.size.width * animatedFraction, isDone || progress.value > 0 ? 10 : 0))
                    }
                }
                .frame(height: 8)

                HStack {
                    if isDone {
                        Text(L("challenge.done.title"))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Theme.seenGreen)
                        Spacer()
                        Text(L("challenge.done.msg"))
                            .font(.caption2)
                            .foregroundStyle(Theme.inkSoft)
                    } else {
                        Spacer()
                        Text("\(progress.value)/\(progress.target)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.inkSoft)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                }
            }

            friendChallengeButton
        }
        .padding(16)
        .background(Theme.card, in: .rect(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke((isDone ? Theme.seenGreen : Theme.rose).opacity(0.25), lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            if celebrating {
                Text("🎉")
                    .font(.system(size: 30))
                    .offset(x: -6, y: -12)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .sensoryFeedback(.success, trigger: celebrating)
        .sheet(isPresented: $showDuoChallenge) {
            ChallengeDuoView()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.85).delay(0.15)) {
                animatedFraction = isDone ? 1 : progress.fraction
            }
            completeIfNeeded(progress)
        }
        .onChange(of: progress.value) { _, _ in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                animatedFraction = progress.fraction
            }
            completeIfNeeded(progress)
        }
    }

    /// "Sfida un amico" (Premium): run this month's challenge together via
    /// a shareable code, with side-by-side progress.
    private var friendChallengeButton: some View {
        let isPremium = PremiumStore.shared.isPremium
        let isPaired = UserDefaults.standard.string(forKey: "chduo.month") == challenge.id
            && !(UserDefaults.standard.string(forKey: "chduo.code") ?? "").isEmpty

        return Button {
            if isPremium {
                showDuoChallenge = true
            } else {
                showPaywall = true
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isPremium ? "person.2.fill" : "lock.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text(L(isPaired ? "chduo.active" : "chduo.title"))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                if !isPremium {
                    Text(L("premium.locked"))
                        .font(.caption2)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .foregroundStyle(Theme.amber)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(Theme.amber.opacity(0.12), in: .rect(cornerRadius: 11))
            .overlay(
                RoundedRectangle(cornerRadius: 11)
                    .stroke(Theme.amber.opacity(0.35), lineWidth: 1)
            )
        }
        .sensoryFeedback(.impact(weight: .light), trigger: showDuoChallenge)
    }

    /// First time the target is reached: persist + celebrate.
    private func completeIfNeeded(_ progress: ChallengeProgress) {
        guard progress.isComplete, !store.isCompleted(challenge.id) else { return }
        store.markCompleted(challenge.id)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
            celebrating = true
        }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(.easeOut(duration: 0.4)) {
                celebrating = false
            }
        }
    }
}
