//
//  MoodFlowView.swift
//  MoodE
//

import SwiftUI

/// Guided 3-step flow: emotion → goal → era, with animated transitions.
struct MoodFlowView: View {
    @State private var step: Int = 0
    @State private var isMovingForward: Bool = true

    @State private var selectedMood: Mood?
    @State private var selectedGoal: ViewingGoal?
    @State private var selectedEra: MovieEra?

    @State private var resultSelection: MoodSelection?

    private let gridColumns: [GridItem] = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private let goalColumns: [GridItem] = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, 24)
                .padding(.top, 8)

            ZStack {
                switch step {
                case 0: moodStep.transition(stepTransition)
                case 1: goalStep.transition(stepTransition)
                default: eraStep.transition(stepTransition)
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: step)

            bottomBar
                .padding(.horizontal, 24)
                .padding(.bottom, 6)
        }
        .navigationDestination(item: $resultSelection) { selection in
            MovieResultsView(selection: selection)
        }
    }

    // MARK: - Steps

    private var moodStep: some View {
        stepScreen(
            title: "Come ti senti oggi?",
            subtitle: "Scegli l'emozione che ti rappresenta di più in questo momento."
        ) {
            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(Array(Mood.allCases.enumerated()), id: \.element) { index, mood in
                    SelectableCard(
                        emoji: mood.emoji,
                        icon: mood.icon,
                        title: mood.title,
                        isSelected: selectedMood == mood,
                        tint: mood.tint,
                        animatesEmoji: true,
                        animationIndex: index
                    ) {
                        selectedMood = mood
                    }
                }
            }
        }
    }

    private var goalStep: some View {
        stepScreen(
            title: "Cosa vuoi ottenere guardando un film?",
            subtitle: "Dimmi che effetto cerchi: sceglieremo il film giusto per te."
        ) {
            LazyVGrid(columns: goalColumns, spacing: 12) {
                ForEach(Array(ViewingGoal.allCases.enumerated()), id: \.element) { index, goal in
                    SelectableCard(
                        emoji: goal.emoji,
                        icon: goal.icon,
                        title: goal.title,
                        isSelected: selectedGoal == goal,
                        tint: goal.tint,
                        animatesEmoji: true,
                        animationIndex: index
                    ) {
                        selectedGoal = goal
                    }
                }
            }
        }
    }

    private var eraStep: some View {
        stepScreen(
            title: "Che epoca preferisci?",
            subtitle: "Un ultimo tocco: da quale periodo vuoi che arrivi il tuo film?"
        ) {
            VStack(spacing: 12) {
                ForEach(MovieEra.allCases) { era in
                    SelectableRow(
                        emoji: era.emoji,
                        title: era.title,
                        subtitle: era.subtitle,
                        isSelected: selectedEra == era,
                        tint: era.tint
                    ) {
                        selectedEra = era
                    }
                }
            }
        }
    }

    private func stepScreen<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Theme.ink)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                content()
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Chrome

    private var topBar: some View {
        HStack(spacing: 14) {
            Button {
                goBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(step == 0 ? Theme.inkSoft.opacity(0.3) : Theme.primary)
                    .frame(width: 36, height: 36)
                    .background(Theme.card, in: .circle)
            }
            .disabled(step == 0)

            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? Theme.primary : Theme.primary.opacity(0.15))
                        .frame(height: 5)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: step)
                }
            }

            Text("\(step + 1)/3")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.inkSoft)
                .monospacedDigit()
        }
    }

    private var bottomBar: some View {
        Button {
            advance()
        } label: {
            HStack(spacing: 7) {
                Text(step == 2 ? "Trova il mio film" : "Continua")
                    .font(.subheadline.weight(.semibold))
                if step == 2 {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                } else {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(
                canAdvance ? Theme.primary : Theme.primary.opacity(0.35),
                in: .rect(cornerRadius: 14)
            )
        }
        .disabled(!canAdvance)
        .sensoryFeedback(.impact(weight: .medium), trigger: step)
        .animation(.easeInOut(duration: 0.2), value: canAdvance)
    }

    // MARK: - Logic

    private var canAdvance: Bool {
        switch step {
        case 0: return selectedMood != nil
        case 1: return selectedGoal != nil
        default: return selectedEra != nil
        }
    }

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: isMovingForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: isMovingForward ? .leading : .trailing).combined(with: .opacity)
        )
    }

    private func advance() {
        if step < 2 {
            isMovingForward = true
            withAnimation { step += 1 }
        } else if let mood = selectedMood, let goal = selectedGoal, let era = selectedEra {
            let selection = MoodSelection(mood: mood, goal: goal, era: era)
            // Interstitial al massimo 1 ogni 3 ricerche, poi si aprono i risultati.
            AdsManager.shared.showSearchInterstitialIfDue {
                resultSelection = selection
            }
        }
    }

    private func goBack() {
        guard step > 0 else { return }
        isMovingForward = false
        withAnimation { step -= 1 }
    }
}

#Preview {
    NavigationStack {
        ZStack {
            Theme.background.ignoresSafeArea()
            MoodFlowView()
        }
    }
}
