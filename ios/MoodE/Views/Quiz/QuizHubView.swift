//
//  QuizHubView.swift
//  MoodE
//

import SwiftUI

/// "Quiz": the list of every quiz available, plus the door to the collection of
/// kept results. Reachable from the Home strip and from Impostazioni, and
/// reserved to Premium subscribers like the rest of the quiz feature.
struct QuizHubView: View {
    @Environment(QuizStore.self) private var quiz

    /// True when shown as a sheet from Home: adds its own close button.
    var isPresentedAsSheet: Bool = false

    @Environment(\.dismiss) private var dismiss

    private var quizzes: [QuizDefinition] { QuizCatalog.all }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    header

                    ForEach(quizzes) { definition in
                        NavigationLink(value: definition) {
                            card(definition)
                        }
                        .buttonStyle(PressableCardStyle())
                    }

                    historyRow
                        .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(L("quiz.hub.title"))
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
        .navigationDestination(for: QuizDefinition.self) { definition in
            QuizPlayerView(definition: definition)
        }
        .navigationDestination(for: QuizResult.self) { result in
            QuizSavedResultView(result: result)
        }
        // "Che serata guardi stasera?" ends on a ready-made suggestion that
        // opens the regular results screen.
        .navigationDestination(for: MoodSelection.self) { selection in
            MovieResultsView(selection: selection)
        }
    }

    private var header: some View {
        Text(L("quiz.hub.subtitle"))
            .font(.footnote)
            .foregroundStyle(Theme.inkSoft)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }

    // MARK: - Quiz card

    private func card(_ definition: QuizDefinition) -> some View {
        let latest = quiz.latestResult(forQuiz: definition.id)
        let latestOutcome = latest.flatMap { definition.outcome(id: $0.outcomeId) }

        return HStack(spacing: 14) {
            emblem(definition)

            VStack(alignment: .leading, spacing: 4) {
                Text(definition.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)

                Text(definition.tagline)
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Text(LF("quiz.hub.meta", definition.questions.count))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.inkSoft)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.inkSoft.opacity(0.10), in: .capsule)

                    if let latestOutcome {
                        Text("\(latestOutcome.emoji) \(latestOutcome.title)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(latestOutcome.gradient.first ?? Theme.primary)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background((latestOutcome.gradient.first ?? Theme.primary).opacity(0.12), in: .capsule)
                    }
                }
                .padding(.top, 2)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.inkSoft.opacity(0.5))
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Theme.card, in: .rect(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke((definition.kind.gradient.first ?? Theme.primary).opacity(0.18), lineWidth: 1)
        )
        .contentShape(.rect)
    }

    private func emblem(_ definition: QuizDefinition) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: definition.kind.gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 54, height: 54)
                .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))
                .shadow(color: (definition.kind.gradient.first ?? .black).opacity(0.32), radius: 8, y: 4)

            if EmojiSupport.isAvailable {
                Text(definition.kind.emoji)
                    .font(.system(size: 24))
            } else {
                Image(systemName: definition.kind.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Collection row

    private var historyRow: some View {
        NavigationLink {
            QuizHistoryView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(
                        LinearGradient(
                            colors: [Theme.amber, Theme.rose],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: .circle
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(L("quiz.history.title"))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.ink)
                    Text(keptSubtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft.opacity(0.5))
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(Theme.card, in: .rect(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Theme.amber.opacity(0.20), lineWidth: 1)
            )
            .contentShape(.rect)
        }
        .buttonStyle(PressableCardStyle())
    }

    private var keptSubtitle: String {
        let count = quiz.savedResults.count
        return count == 0 ? L("quiz.history.empty.title") : LF("quiz.history.count", count)
    }
}

#Preview {
    NavigationStack {
        QuizHubView()
    }
    .environment(QuizStore())
    .environment(PersonalizationStore())
    .environment(MoodDiary())
    .environment(MovieLibrary())
    .environment(MoviePlanner())
}
