//
//  DailyQuizCard.swift
//  MoodE
//

import SwiftUI

/// Home card proposing one quiz a day, picked from the user's own history
/// (see `DailyQuizStore`). It opens the quiz straight away instead of going
/// through the hub, disappears once that quiz is played, and can be hidden
/// for the day with a long press.
struct DailyQuizCard: View {
    @Environment(QuizStore.self) private var quiz

    private var store: DailyQuizStore { .shared }
    private var isPremium: Bool { PremiumStore.shared.isPremium }

    /// Quiz being played. Held separately from `store.current` so the sheet
    /// keeps its content even when the card retires itself mid-play (finishing
    /// the quiz updates the suggestion underneath).
    @State private var playingQuiz: QuizDefinition?
    @State private var showPaywall: Bool = false
    /// Drives the slow breathing glow behind the emblem.
    @State private var isGlowing: Bool = false

    var body: some View {
        Group {
            if let suggestion = store.current {
                card(suggestion)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .scale(scale: 0.94))
                    ))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: store.current)
        .task {
            store.refresh(using: quiz)
            if store.current != nil {
                isGlowing = true
                AnalyticsService.shared.log(
                    "daily_quiz_shown",
                    meta: ["quiz": store.current?.definition.id ?? ""]
                )
            }
        }
        // Playing the quiz retires the card for the day.
        .onChange(of: quiz.playDates) { _, _ in
            store.refresh(using: quiz)
        }
        .sheet(item: $playingQuiz) { definition in
            QuizPlayerSheet(definition: definition)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    // MARK: - Card

    private func card(_ suggestion: DailyQuizSuggestion) -> some View {
        let gradient = suggestion.definition.kind.gradient
        let accent = gradient.first ?? Theme.primary

        return Button {
            open(suggestion)
        } label: {
            HStack(spacing: 13) {
                emblem(suggestion, gradient: gradient)

                VStack(alignment: .leading, spacing: 3) {
                    label(accent: accent)

                    Text(suggestion.definition.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    Text(suggestion.reason)
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if let outcome = suggestion.previousOutcome {
                        previousChip(outcome)
                            .padding(.top, 3)
                    }
                }

                Spacer(minLength: 0)

                ctaPill(accent: accent)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            // Card colour plus a soft diagonal wash in the quiz's own tint,
            // so every suggestion arrives with a slightly different mood.
            .background {
                RoundedRectangle(cornerRadius: 22)
                    .fill(Theme.card)
                    .overlay {
                        RoundedRectangle(cornerRadius: 22)
                            .fill(
                                LinearGradient(
                                    colors: [accent.opacity(0.16), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(accent.opacity(0.28), lineWidth: 1)
            )
            .contentShape(.rect)
        }
        .buttonStyle(PressableCardStyle())
        .sensoryFeedback(.impact(weight: .light), trigger: playingQuiz)
        .contextMenu {
            Section("\(suggestion.definition.title) — \(suggestion.reason)") {
                Button {
                    open(suggestion)
                } label: {
                    Label(L("quiz.start"), systemImage: "play.circle")
                }
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        store.hideForToday()
                    }
                } label: {
                    Label(L("quiz.daily.hide"), systemImage: "xmark")
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(L("quiz.daily.label")). \(suggestion.definition.title). \(suggestion.reason)")
        .accessibilityHint(isPremium ? L("quiz.start") : L("premium.locked"))
    }

    private func label(accent: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.system(size: 9, weight: .bold))
            Text(L("quiz.daily.label").uppercased())
                .font(.system(size: 9, weight: .heavy))
                .tracking(0.6)
        }
        .foregroundStyle(accent)
    }

    private func emblem(_ suggestion: DailyQuizSuggestion, gradient: [Color]) -> some View {
        ZStack {
            // Breathing halo: the only motion on the card, slow enough to
            // read as ambience rather than an alert.
            Circle()
                .fill(gradient.first?.opacity(0.35) ?? Theme.primary.opacity(0.35))
                .frame(width: 52, height: 52)
                .blur(radius: 9)
                .scaleEffect(isGlowing ? 1.12 : 0.9)
                .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: isGlowing)

            Circle()
                .fill(
                    LinearGradient(
                        colors: gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 48, height: 48)
                .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))

            if EmojiSupport.isAvailable {
                Text(suggestion.definition.kind.emoji)
                    .font(.system(size: 22))
            } else {
                Image(systemName: suggestion.definition.kind.icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
            }

            if !isPremium {
                Image(systemName: "lock.fill")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 14, height: 14)
                    .background(Theme.ink.opacity(0.85), in: .circle)
                    .offset(x: 18, y: 18)
            }
        }
    }

    private func previousChip(_ outcome: QuizOutcome) -> some View {
        let tint = outcome.gradient.first ?? Theme.primary
        return Text("\(outcome.emoji) \(outcome.title)")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.12), in: .capsule)
    }

    private func ctaPill(accent: Color) -> some View {
        HStack(spacing: 3) {
            Text(L("quiz.daily.cta"))
                .font(.caption2.weight(.bold))
            Image(systemName: "arrow.right")
                .font(.system(size: 9, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(accent, in: .capsule)
    }

    // MARK: - Actions

    private func open(_ suggestion: DailyQuizSuggestion) {
        guard isPremium else {
            showPaywall = true
            return
        }
        AnalyticsService.shared.log(
            "daily_quiz_opened",
            meta: ["quiz": suggestion.definition.id]
        )
        playingQuiz = suggestion.definition
    }
}
