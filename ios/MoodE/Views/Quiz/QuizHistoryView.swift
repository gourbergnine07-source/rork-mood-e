//
//  QuizHistoryView.swift
//  MoodE
//

import SwiftUI

/// "I miei risultati quiz": every result the user chose to keep, newest first.
/// Each row reopens the full result screen (with the same four actions) and can
/// be removed at any time.
struct QuizHistoryView: View {
    @Environment(QuizStore.self) private var quiz

    @State private var pendingRemoval: QuizResult?

    private var results: [QuizResult] {
        quiz.savedResults.filter(\.isRenderable)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if results.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        Text(L("quiz.history.subtitle"))
                            .font(.footnote)
                            .foregroundStyle(Theme.inkSoft)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)

                        ForEach(results) { result in
                            row(result)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle(L("quiz.history.title"))
        .toolbarTitleDisplayMode(.inline)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: results.count)
        .alert(
            L("quiz.remove.title"),
            isPresented: Binding(
                get: { pendingRemoval != nil },
                set: { if !$0 { pendingRemoval = nil } }
            )
        ) {
            Button(L("common.cancel"), role: .cancel) { pendingRemoval = nil }
            Button(L("common.delete"), role: .destructive) {
                if let pendingRemoval {
                    withAnimation { quiz.remove(pendingRemoval) }
                }
                pendingRemoval = nil
            }
        } message: {
            Text(L("quiz.remove.msg"))
        }
    }

    @ViewBuilder
    private func row(_ result: QuizResult) -> some View {
        if let definition = result.definition, let outcome = result.outcome {
            HStack(spacing: 10) {
                NavigationLink(value: result) {
                    HStack(spacing: 12) {
                        QuizEmblem(outcome: outcome, size: 46)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(definition.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.inkSoft)
                                .lineLimit(1)

                            Text(outcome.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)

                            HStack(spacing: 6) {
                                Text(result.formattedDate)
                                    .font(.caption2)
                                    .foregroundStyle(Theme.inkSoft)
                                if let scoreText = result.scoreText {
                                    Text(scoreText)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(outcome.gradient.first ?? Theme.primary)
                                        .monospacedDigit()
                                }
                            }
                        }

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.inkSoft.opacity(0.5))
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(PressableCardStyle())
                .accessibilityHint(L("quiz.history.open"))

                Button {
                    pendingRemoval = result
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.rose)
                        .frame(width: 32, height: 32)
                        .background(Theme.rose.opacity(0.10), in: .circle)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L("quiz.remove"))
            }
            .padding(12)
            .background(Theme.card, in: .rect(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Theme.primary.opacity(0.10), lineWidth: 1)
            )
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bookmark.slash")
                .font(.system(size: 42))
                .foregroundStyle(Theme.inkSoft.opacity(0.6))
            Text(L("quiz.history.empty.title"))
                .font(.headline)
                .foregroundStyle(Theme.ink)
            Text(L("quiz.history.empty.msg"))
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}

/// Wrapper used by the navigation destination: resolves a kept result back to
/// its quiz and shows the shared result screen, popping when it is removed.
struct QuizSavedResultView: View {
    let result: QuizResult

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if let definition = result.definition {
                QuizResultView(definition: definition, result: result, onRetake: nil) {
                    dismiss()
                }
            } else {
                Text(L("quiz.result.unavailable"))
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(32)
            }
        }
        .navigationTitle(result.definition?.title ?? L("quiz.hub.title"))
        .toolbarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        QuizHistoryView()
    }
    .environment(QuizStore())
}
