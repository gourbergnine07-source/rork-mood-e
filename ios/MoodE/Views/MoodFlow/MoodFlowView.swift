//
//  MoodFlowView.swift
//  MoodE
//

import SwiftUI

/// Guided 3-step flow: emotion → goal → era, with animated transitions.
struct MoodFlowView: View {
    @Environment(MoodDiary.self) private var diary
    @Environment(QuizStore.self) private var quiz
    @State private var step: Int = 0
    @State private var isMovingForward: Bool = true
    @State private var showQuickPickHint: Bool = false

    @State private var selectedMood: Mood?
    @State private var selectedGoal: ViewingGoal?
    @State private var selectedEra: MovieEra?

    @State private var resultSelection: MoodSelection?
    @State private var showSurprise: Bool = false
    @State private var showQuiz: Bool = false
    @State private var showDuo: Bool = false
    @State private var showPaywall: Bool = false

    // Free-form mood input (STEP 1 alternative), analyzed by AI.
    @State private var freeText: String = ""
    @State private var isAnalyzing: Bool = false
    @State private var interpretation: MoodInterpretation?
    @State private var analysisFailed: Bool = false
    /// Session-only dismissal: the quiz banner returns at every app launch.
    @State private var quizBannerHidden: Bool = false

    private let gridColumns: [GridItem] = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
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
        .navigationDestination(for: FeaturedCollection.self) { collection in
            FeaturedCollectionView(collection: collection)
        }
        .sheet(isPresented: $showSurprise) {
            SurpriseView()
        }
        .sheet(isPresented: $showDuo) {
            DuoNightView()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showQuiz) {
            NavigationStack {
                SpectatorQuizView(isPresentedAsSheet: true)
            }
            .tint(Theme.primary)
        }
        .onReceive(NotificationCenter.default.publisher(for: ForecastLaunch.name)) { note in
            guard let selection = note.object as? MoodSelection else { return }
            resultSelection = selection
        }
        .alert(L("flow.quick.alert.title"), isPresented: $showQuickPickHint) {
            Button(L("common.ok"), role: .cancel) {}
        } message: {
            Text(L("flow.quick.alert.msg"))
        }
        .alert(L("common.oops"), isPresented: $analysisFailed) {
            Button(L("common.ok"), role: .cancel) {}
        } message: {
            Text(L("flow.freetext.error"))
        }
        .sheet(item: $interpretation) { interp in
            MoodInterpretationSheet(interpretation: interp) { mood, goal in
                applyInterpretation(mood: mood, goal: goal)
            }
            .presentationDetents([.height(420)])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Steps

    private var moodStep: some View {
        stepScreen(
            title: L("flow.s1.title"),
            subtitle: L("flow.s1.sub"),
            header: {
                MoodFlowHeader(showQuiz: $showQuiz, showPaywall: $showPaywall, quizBannerHidden: $quizBannerHidden)
            }
        ) {
            VStack(spacing: 14) {
                moodGrid
                MoodFreeTextCard(
                    text: $freeText,
                    isAnalyzing: isAnalyzing
                ) {
                    analyzeFreeText()
                }
            }
        }
    }

    private var moodGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 8) {
            ForEach(Array(Mood.allCases.enumerated()), id: \.element) { index, mood in
                SelectableCard(
                    emoji: mood.emoji,
                    icon: mood.icon,
                    title: mood.title,
                    isSelected: selectedMood == mood,
                    tint: mood.tint,
                    animatesEmoji: true,
                    animationIndex: index,
                    isCompact: true
                ) {
                    selectedMood = mood
                }
            }
        }
    }

    private var goalStep: some View {
        stepScreen(
            title: L("flow.s2.title"),
            subtitle: L("flow.s2.sub")
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
            title: L("flow.s3.title"),
            subtitle: L("flow.s3.sub")
        ) {
            VStack(spacing: 12) {
                ForEach(MovieEra.allCases) { era in
                    SelectableRow(
                        emoji: era.emoji,
                        icon: era.icon,
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
        stepScreen(title: title, subtitle: subtitle, header: { EmptyView() }, content: content)
    }

    /// Step layout with an optional full-bleed header above the title
    /// (used on step 1 for the "In evidenza" editorial strip).
    private func stepScreen<Header: View, Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header()

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
            }
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

    /// Compact pill used for the three step-1 shortcuts (quick / surprise / duo),
    /// kept on a single row so the bottom bar covers as little of the grid as possible.
    private func shortcutLabel(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .foregroundStyle(tint)
        .frame(maxWidth: .infinity)
        .frame(height: 32)
        .background(tint.opacity(0.12), in: .rect(cornerRadius: 11))
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .stroke(tint.opacity(0.35), lineWidth: 1)
        )
    }

    private var bottomBar: some View {
        VStack(spacing: 6) {
            Button {
                advance()
            } label: {
                HStack(spacing: 7) {
                    Text(step == 2 ? L("flow.find") : L("flow.continue"))
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
                .frame(height: 40)
                .background(
                    canAdvance ? Theme.primary : Theme.primary.opacity(0.35),
                    in: .rect(cornerRadius: 14)
                )
            }
            .disabled(!canAdvance)
            .sensoryFeedback(.impact(weight: .medium), trigger: step)
            .animation(.easeInOut(duration: 0.2), value: canAdvance)

            if step == 0 {
                HStack(spacing: 8) {
                    Button {
                        startQuickPick()
                    } label: {
                        shortcutLabel(icon: "bolt.fill", title: L("flow.quick"), tint: Theme.amber)
                    }
                    .accessibilityHint(L("flow.quick.hint"))

                    Button {
                        showSurprise = true
                    } label: {
                        shortcutLabel(icon: "dice.fill", title: L("flow.surprise"), tint: Theme.rose)
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: showSurprise)

                    Button {
                        // Serata in Duo è una funzione Premium: il lucchetto
                        // porta al paywall, mai durante il flusso di ricerca.
                        if PremiumStore.shared.isPremium {
                            showDuo = true
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        shortcutLabel(
                            icon: PremiumStore.shared.isPremium ? "person.2.fill" : "lock.fill",
                            title: L("flow.duo"),
                            tint: Theme.tabList
                        )
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: showDuo)
                    .accessibilityHint(PremiumStore.shared.isPremium ? "" : L("premium.locked"))
                }
            }
        }
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
            AnalyticsService.shared.log("flow_completed")
            // Interstitial al massimo 1 ogni 3 ricerche, poi si aprono i risultati.
            AdsManager.shared.showSearchInterstitialIfDue {
                resultSelection = selection
            }
        }
    }

    /// One-tap mode: skips goal and era, deriving them from the mood alone.
    /// Works even without a selected card: falls back to today's check-in
    /// mood, then to the most frequent recent mood from the diary.
    private func startQuickPick() {
        guard let mood = selectedMood ?? inferredQuickPickMood else {
            showQuickPickHint = true
            return
        }
        let selection = MoodSelection(
            mood: mood,
            goal: mood.quickPickGoal,
            era: .noPreference,
            isQuickPick: true
        )
        AnalyticsService.shared.log("quick_pick_used")
        AdsManager.shared.showSearchInterstitialIfDue {
            resultSelection = selection
        }
    }

    /// Mood inferred from the diary when none is selected on screen.
    private var inferredQuickPickMood: Mood? {
        let calendar = Calendar.current
        if let today = diary.checkIns.first(where: { calendar.isDate($0.date, inSameDayAs: Date()) })?.mood {
            return today
        }
        var counts: [String: Int] = [:]
        for checkIn in diary.checkIns.prefix(60) {
            counts[checkIn.moodRaw, default: 0] += 1
        }
        guard let top = counts.max(by: { $0.value < $1.value })?.key else { return nil }
        return Mood(rawValue: top)
    }

    private func goBack() {
        guard step > 0 else { return }
        isMovingForward = false
        withAnimation { step -= 1 }
    }

    // MARK: - Free-text mood analysis

    /// Sends the free-form text to the AI classifier, then shows the
    /// confirmation sheet so the user can correct the interpretation.
    private func analyzeFreeText() {
        let text = freeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 3, !isAnalyzing else { return }
        isAnalyzing = true
        Task {
            do {
                let result = try await MoodTextAnalyzer.shared.analyze(text)
                AnalyticsService.shared.log("mood_text_analyzed")
                interpretation = MoodInterpretation(mood: result.mood, goal: result.goal)
            } catch {
                print("MoodFlow: free-text analysis failed: \(error.localizedDescription)")
                analysisFailed = true
            }
            isAnalyzing = false
        }
    }

    /// Applies the confirmed interpretation: jumps straight to the era step
    /// when a goal was deduced, or to the goal step otherwise.
    private func applyInterpretation(mood: Mood, goal: ViewingGoal?) {
        selectedMood = mood
        freeText = ""
        isMovingForward = true
        if let goal {
            selectedGoal = goal
            withAnimation { step = 2 }
        } else {
            withAnimation { step = 1 }
        }
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
