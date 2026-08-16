//
//  QuizResultView.swift
//  MoodE
//

import SwiftUI

/// Result screen shared by every quiz, both right after playing and when
/// reopened from "I miei risultati quiz".
///
/// Four actions are always available: share the generated card, retake the
/// quiz, keep the result in the permanent collection, and remove it again
/// (with confirmation) once it is kept.
struct QuizResultView: View {
    let definition: QuizDefinition
    let result: QuizResult

    /// Restart in place. Provided by the player; in the history context it is
    /// nil and a push to a fresh run is offered instead.
    var onRetake: (() -> Void)?
    /// Called after the kept result is removed, so the caller can pop.
    var onRemoved: (() -> Void)?

    @Environment(QuizStore.self) private var quiz

    @State private var sharePayload: ShareCardPayload?
    @State private var confirmRemoval: Bool = false
    @State private var justKept: Bool = false
    @State private var progress: Double = 0

    private var outcome: QuizOutcome? { definition.outcome(id: result.outcomeId) }
    private var isKept: Bool { quiz.isKept(result) }

    var body: some View {
        if let outcome {
            content(outcome)
        } else {
            unavailable
        }
    }

    // MARK: - Layout

    private func content(_ outcome: QuizOutcome) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                Text(L("quiz.result.heading"))
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Theme.inkSoft)
                    .textCase(.uppercase)
                    .kerning(1.5)
                    .padding(.top, 12)

                QuizEmblem(outcome: outcome, size: 128)

                Text(outcome.title)
                    .font(.title.weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)

                if definition.scoring == .points {
                    scoreMeter(outcome)
                }

                Text(outcome.detail)
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)

                if definition.kind == .spectator {
                    Text(L("quiz.result.ranking"))
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.center)
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(Theme.primary.opacity(0.08), in: .rect(cornerRadius: 12))
                }

                if let advice = outcome.advice {
                    adviceCard(advice, tint: outcome.gradient.first ?? Theme.primary)
                }

                Text(LF("quiz.result.savedOn", result.formattedDate))
                    .font(.caption2)
                    .foregroundStyle(Theme.inkSoft.opacity(0.8))

                actions(outcome)
            }
            .padding(24)
        }
        .scrollIndicators(.hidden)
        .sheet(item: $sharePayload) { payload in
            ShareCardSheet(payload: payload)
        }
        .alert(L("quiz.remove.title"), isPresented: $confirmRemoval) {
            Button(L("common.cancel"), role: .cancel) {}
            Button(L("common.delete"), role: .destructive) {
                quiz.remove(result)
                onRemoved?()
            }
        } message: {
            Text(L("quiz.remove.msg"))
        }
    }

    /// Animated point meter for the level-based quiz.
    private func scoreMeter(_ outcome: QuizOutcome) -> some View {
        VStack(spacing: 8) {
            if let scoreText = result.scoreText {
                Text(scoreText)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(outcome.gradient.first ?? Theme.primary)
                    .monospacedDigit()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.inkSoft.opacity(0.15))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: outcome.gradient,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(6, geo.size.width * progress))
                }
            }
            .frame(height: 10)
        }
        .padding(.horizontal, 8)
        .onAppear {
            let total = Double(definition.maxPoints)
            let target = total > 0 ? Double(result.points ?? 0) / total : 0
            withAnimation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.15)) {
                progress = target
            }
        }
    }

    /// "Che serata guardi stasera?" ends with a ready-made suggestion: the two
    /// chips show the combination and the button opens the matching picks.
    private func adviceCard(_ advice: MoodSelection, tint: Color) -> some View {
        VStack(spacing: 12) {
            Text(L("quiz.result.advice"))
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .textCase(.uppercase)
                .kerning(1.2)

            HStack(spacing: 8) {
                adviceChip(emoji: advice.mood.emoji, text: advice.mood.title, tint: advice.mood.tint)
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.inkSoft.opacity(0.6))
                adviceChip(emoji: advice.goal.emoji, text: advice.goal.title, tint: advice.goal.tint)
            }

            NavigationLink(value: advice) {
                Label(L("quiz.result.advice.cta"), systemImage: "popcorn.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(tint, in: .rect(cornerRadius: 14))
            }
            .buttonStyle(PressableCardStyle())
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Theme.card, in: .rect(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        )
    }

    private func adviceChip(emoji: String, text: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Text(emoji).font(.system(size: 13))
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.14), in: .capsule)
    }

    // MARK: - Actions

    private func actions(_ outcome: QuizOutcome) -> some View {
        VStack(spacing: 10) {
            Button {
                share(outcome)
            } label: {
                Label(L("quiz.share"), systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Theme.primary, in: .rect(cornerRadius: 14))
            }
            .buttonStyle(PressableCardStyle())
            .sensoryFeedback(.impact(weight: .medium), trigger: sharePayload?.id)

            HStack(spacing: 10) {
                retakeButton
                keepButton
            }

            if isKept {
                Button(role: .destructive) {
                    confirmRemoval = true
                } label: {
                    Label(L("quiz.remove"), systemImage: "trash")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.rose)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Theme.rose.opacity(0.10), in: .rect(cornerRadius: 14))
                }
                .buttonStyle(PressableCardStyle())
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isKept)
        .padding(.top, 4)
    }

    @ViewBuilder
    private var retakeButton: some View {
        if let onRetake {
            Button {
                onRetake()
            } label: {
                retakeLabel
            }
            .buttonStyle(PressableCardStyle())
        } else {
            // Reopened from the collection: start a brand new run instead.
            NavigationLink(value: definition) {
                retakeLabel
            }
            .buttonStyle(PressableCardStyle())
        }
    }

    private var retakeLabel: some View {
        Label(L("quiz.retake"), systemImage: "arrow.clockwise")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(Theme.primary.opacity(0.10), in: .rect(cornerRadius: 14))
    }

    private var keepButton: some View {
        Button {
            quiz.keep(result)
            justKept = true
        } label: {
            Label(
                isKept ? L("quiz.kept") : L("quiz.keep"),
                systemImage: isKept ? "checkmark.seal.fill" : "bookmark"
            )
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isKept ? Theme.seenGreen : .white)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(
                isKept ? Theme.seenGreen.opacity(0.14) : Theme.amber,
                in: .rect(cornerRadius: 14)
            )
            .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(PressableCardStyle())
        .disabled(isKept)
        .sensoryFeedback(.success, trigger: justKept)
        .accessibilityLabel(isKept ? L("quiz.kept") : L("quiz.keep"))
    }

    private func share(_ outcome: QuizOutcome) {
        let card = QuizShareCardView(
            quizTitle: definition.title,
            outcome: outcome,
            scoreText: result.scoreText
        )
        guard let image = ShareCardRenderer.render(card) else { return }
        sharePayload = ShareCardPayload(image: image, title: outcome.title)
    }

    /// Kept result whose quiz changed in a later app version.
    private var unavailable: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.folder")
                .font(.system(size: 40))
                .foregroundStyle(Theme.inkSoft)
            Text(L("quiz.result.unavailable"))
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}

/// Circular emblem of an outcome: gradient disc plus emoji, with an SF Symbol
/// fallback for devices where the emoji font is unavailable.
struct QuizEmblem: View {
    let outcome: QuizOutcome
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: outcome.gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: (outcome.gradient.first ?? .black).opacity(0.4), radius: size * 0.14, y: size * 0.06)

            if EmojiSupport.isAvailable {
                Text(outcome.emoji)
                    .font(.system(size: size * 0.45))
            } else {
                Image(systemName: outcome.icon)
                    .font(.system(size: size * 0.36, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
    }
}
