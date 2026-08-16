//
//  QuizPlayerView.swift
//  MoodE
//

import SwiftUI

/// Runs any quiz of the catalog: intro, one question per screen, then the
/// result. There is no limit on how many times a quiz can be played, and the
/// result is only added to the collection when the user taps "Conserva".
struct QuizPlayerView: View {
    let definition: QuizDefinition

    @Environment(QuizStore.self) private var quiz
    @Environment(PersonalizationStore.self) private var personalization
    @Environment(MoodDiary.self) private var diary
    @Environment(MovieLibrary.self) private var library
    @Environment(MoviePlanner.self) private var planner

    private enum Stage: Equatable {
        case intro
        case question(Int)
        case result(QuizResult)
    }

    @State private var stage: Stage = .intro
    @State private var answers: [String: QuizOption] = [:]

    private var questions: [QuizQuestion] { definition.questions }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            switch stage {
            case .intro:
                introView
                    .transition(.opacity)
            case .question(let index):
                questionView(index)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    .id(index)
            case .result(let result):
                QuizResultView(definition: definition, result: result) {
                    restart()
                }
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: stage)
        .navigationTitle(definition.title)
        .toolbarTitleDisplayMode(.inline)
    }

    // MARK: - Intro

    private var introView: some View {
        VStack(spacing: 20) {
            Spacer()

            if EmojiSupport.isAvailable {
                Text(definition.kind.emoji)
                    .font(.system(size: 64))
            } else {
                Image(systemName: definition.kind.icon)
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(Theme.primary)
            }

            Text(definition.title)
                .font(.title.weight(.bold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)

            Text(definition.introMessage)
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            Text(LF("quiz.hub.meta", questions.count))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.inkSoft)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.primary.opacity(0.10), in: .capsule)

            if let latest = quiz.latestResult(forQuiz: definition.id),
               let outcome = definition.outcome(id: latest.outcomeId) {
                lastKeptCard(latest, outcome: outcome)
            }

            Spacer()

            Button {
                restart()
            } label: {
                Text(quiz.results(forQuiz: definition.id).isEmpty ? L("quiz.start") : L("quiz.retake"))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Theme.primary, in: .rect(cornerRadius: 14))
            }
            .buttonStyle(PressableCardStyle())
            .sensoryFeedback(.impact(weight: .medium), trigger: stage)
        }
        .padding(24)
    }

    private func lastKeptCard(_ result: QuizResult, outcome: QuizOutcome) -> some View {
        HStack(spacing: 10) {
            QuizEmblem(outcome: outcome, size: 38)

            VStack(alignment: .leading, spacing: 1) {
                Text(L("quiz.hub.last"))
                    .font(.caption2)
                    .foregroundStyle(Theme.inkSoft)
                Text(outcome.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button {
                withAnimation { stage = .result(result) }
            } label: {
                Text(L("quiz.viewResult"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.primary)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Theme.card, in: .rect(cornerRadius: 16))
    }

    // MARK: - Questions

    private func questionView(_ index: Int) -> some View {
        let question = questions[index]

        return VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Button {
                    goBack(from: index)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                        .frame(width: 36, height: 36)
                        .background(Theme.card, in: .circle)
                }
                .accessibilityLabel(L("common.back"))

                HStack(spacing: 6) {
                    ForEach(questions.indices, id: \.self) { step in
                        Capsule()
                            .fill(step <= index ? Theme.primary : Theme.primary.opacity(0.15))
                            .frame(height: 5)
                    }
                }

                Text("\(index + 1)/\(questions.count)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .monospacedDigit()
            }

            Text(question.prompt(prefix: definition.keyPrefix))
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 12) {
                ForEach(question.options) { option in
                    optionButton(option, question: question, index: index)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(24)
    }

    private func optionButton(_ option: QuizOption, question: QuizQuestion, index: Int) -> some View {
        let isSelected = answers[question.id]?.id == option.id

        return Button {
            answers[question.id] = option
            advance(from: index)
        } label: {
            HStack(spacing: 12) {
                Text(option.emoji)
                    .font(.system(size: 24))
                    .frame(width: 38, height: 38)
                    .background(Theme.primary.opacity(0.10), in: .circle)

                Text(option.text(prefix: definition.keyPrefix, question: question.id))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(14)
            .background(isSelected ? Theme.primary.opacity(0.14) : Theme.card, in: .rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Theme.primary : Theme.ink.opacity(0.06), lineWidth: 1.5)
            )
            .contentShape(.rect)
        }
        .buttonStyle(PressableCardStyle())
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    // MARK: - Flow

    private func restart() {
        answers = [:]
        withAnimation { stage = .question(0) }
    }

    private func advance(from index: Int) {
        if index + 1 < questions.count {
            withAnimation { stage = .question(index + 1) }
            return
        }
        let result = quiz.complete(definition, answers: answers)
        // Finishing any quiz can unlock the "Velluto" theme.
        personalization.evaluate(
            diary: diary,
            library: library,
            planner: planner,
            quizCompleted: true
        )
        withAnimation { stage = .result(result) }
    }

    private func goBack(from index: Int) {
        withAnimation {
            stage = index == 0 ? .intro : .question(index - 1)
        }
    }
}

#Preview {
    NavigationStack {
        QuizPlayerView(definition: QuizCatalog.cinephile)
    }
    .environment(QuizStore())
    .environment(PersonalizationStore())
    .environment(MoodDiary())
    .environment(MovieLibrary())
    .environment(MoviePlanner())
}
