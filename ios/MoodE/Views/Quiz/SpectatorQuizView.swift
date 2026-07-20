//
//  SpectatorQuizView.swift
//  MoodE
//

import SwiftUI

/// Interactive "Che spettatore sei?" quiz: 6 multiple-choice questions
/// assigning one of six cinematic profiles. The result is saved locally,
/// shareable as an image and gently refines the recommendations.
struct SpectatorQuizView: View {
    @Environment(QuizStore.self) private var quiz
    @Environment(PersonalizationStore.self) private var personalization
    @Environment(MoodDiary.self) private var diary
    @Environment(MovieLibrary.self) private var library
    @Environment(MoviePlanner.self) private var planner
    @Environment(\.dismiss) private var dismiss

    private enum Stage: Equatable {
        case intro
        case question(Int)
        case result(SpectatorProfile)
    }

    @State private var stage: Stage = .intro
    @State private var answers: [String: QuizOption] = [:]
    @State private var sharePayload: ShareCardPayload?

    /// True when pushed from Impostazioni (shows its own nav bar);
    /// false when presented as a sheet from Home.
    var isPresentedAsSheet: Bool = false

    private let questions = SpectatorQuiz.questions

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
            case .result(let profile):
                resultView(profile)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: stage)
        .navigationTitle(L("quiz.title"))
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            if isPresentedAsSheet {
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
        .sheet(item: $sharePayload) { payload in
            ShareCardSheet(payload: payload)
        }
    }

    // MARK: - Intro

    private var introView: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("🎭")
                .font(.system(size: 64))

            Text(L("quiz.title"))
                .font(.title.weight(.bold))
                .foregroundStyle(Theme.ink)

            Text(L("quiz.intro.msg"))
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            if let profile = quiz.profile {
                HStack(spacing: 10) {
                    Text(profile.emoji)
                        .font(.system(size: 26))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(L("quiz.settings.current"))
                            .font(.caption)
                            .foregroundStyle(Theme.inkSoft)
                        Text(profile.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.ink)
                    }
                    Spacer()
                    Button {
                        withAnimation { stage = .result(profile) }
                    } label: {
                        Text(L("quiz.viewResult"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.primary)
                    }
                }
                .padding(14)
                .background(Theme.card, in: .rect(cornerRadius: 16))
            }

            Spacer()

            Button {
                answers = [:]
                withAnimation { stage = .question(0) }
            } label: {
                Text(quiz.profile == nil ? L("quiz.start") : L("quiz.retake"))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Theme.primary, in: .rect(cornerRadius: 14))
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: stage)
        }
        .padding(24)
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

            Text(question.prompt)
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

                Text(option.text(question: question.id))
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

    private func advance(from index: Int) {
        if index + 1 < questions.count {
            withAnimation { stage = .question(index + 1) }
        } else {
            let profile = quiz.complete(answers: answers)
            // Completing the quiz can unlock the "Velluto" theme.
            personalization.evaluate(
                diary: diary,
                library: library,
                planner: planner,
                quizCompleted: true
            )
            withAnimation { stage = .result(profile) }
        }
    }

    private func goBack(from index: Int) {
        withAnimation {
            stage = index == 0 ? .intro : .question(index - 1)
        }
    }

    // MARK: - Result

    private func resultView(_ profile: SpectatorProfile) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                Text(L("quiz.result.heading"))
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Theme.inkSoft)
                    .textCase(.uppercase)
                    .kerning(1.5)
                    .padding(.top, 12)

                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: profile.gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 128, height: 128)
                        .shadow(color: (profile.gradient.first ?? .black).opacity(0.4), radius: 18, y: 8)

                    if EmojiSupport.isAvailable {
                        Text(profile.emoji)
                            .font(.system(size: 58))
                    } else {
                        Image(systemName: profile.icon)
                            .font(.system(size: 46, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }

                Text(profile.title)
                    .font(.title.weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)

                Text(profile.detail)
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)

                Text(L("quiz.result.ranking"))
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(Theme.primary.opacity(0.08), in: .rect(cornerRadius: 12))

                VStack(spacing: 10) {
                    Button {
                        shareProfile(profile)
                    } label: {
                        Label(L("quiz.share"), systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Theme.primary, in: .rect(cornerRadius: 14))
                    }
                    .sensoryFeedback(.impact(weight: .medium), trigger: sharePayload?.id)

                    Button {
                        answers = [:]
                        withAnimation { stage = .question(0) }
                    } label: {
                        Text(L("quiz.retake"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Theme.primary.opacity(0.10), in: .rect(cornerRadius: 14))
                    }
                }
                .padding(.top, 6)
            }
            .padding(24)
        }
        .scrollIndicators(.hidden)
    }

    private func shareProfile(_ profile: SpectatorProfile) {
        let card = QuizShareCardView(profile: profile)
        guard let image = ShareCardRenderer.render(card) else { return }
        sharePayload = ShareCardPayload(image: image, title: profile.title)
    }
}

#Preview {
    NavigationStack {
        SpectatorQuizView()
    }
    .environment(QuizStore())
    .environment(PersonalizationStore())
    .environment(MoodDiary())
    .environment(MovieLibrary())
    .environment(MoviePlanner())
}
