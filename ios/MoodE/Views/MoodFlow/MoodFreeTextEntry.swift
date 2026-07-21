//
//  MoodFreeTextEntry.swift
//  MoodE
//
//  Free-form mood input: text (or native keyboard dictation) analyzed by AI,
//  with a confirmation sheet before continuing the flow.
//

import SwiftUI

/// AI interpretation shown for confirmation before jumping ahead in the flow.
struct MoodInterpretation: Identifiable {
    let id = UUID()
    let mood: Mood
    let goal: ViewingGoal?
}

/// "Or tell us in your own words" card under the emotion grid.
/// Dictation comes free with the native keyboard microphone.
struct MoodFreeTextCard: View {
    @Binding var text: String
    let isAnalyzing: Bool
    let onAnalyze: () -> Void

    private var canSend: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.primary)
                Text(L("flow.freetext.title"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.ink)
            }

            HStack(alignment: .bottom, spacing: 8) {
                TextField(L("flow.freetext.placeholder"), text: $text, axis: .vertical)
                    .lineLimit(1...3)
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Theme.surface.opacity(0.7), in: .rect(cornerRadius: 12))
                    .disabled(isAnalyzing)

                Button(action: onAnalyze) {
                    Group {
                        if isAnalyzing {
                            ProgressView()
                                .tint(.white)
                                .controlSize(.small)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 38, height: 38)
                    .background(
                        canSend ? Theme.primary : Theme.primary.opacity(0.35),
                        in: .circle
                    )
                }
                .disabled(!canSend || isAnalyzing)
                .accessibilityLabel(L("flow.freetext.analyze"))
            }

            Label(L("flow.freetext.hint"), systemImage: "mic.fill")
                .font(.caption2)
                .foregroundStyle(Theme.inkSoft.opacity(0.85))
        }
        .padding(14)
        .background(Theme.card, in: .rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Theme.primary.opacity(0.14), lineWidth: 1)
        )
    }
}

/// Shows what the AI understood (mood + optional goal), always correctable
/// before continuing — so a wrong interpretation never slips through.
struct MoodInterpretationSheet: View {
    let interpretation: MoodInterpretation
    let onConfirm: (Mood, ViewingGoal?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var mood: Mood = .felice
    @State private var goal: ViewingGoal?
    @State private var seeded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text(L("interpret.title"))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.ink)
                Text(L("interpret.sub"))
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
            }

            moodRow
            goalRow

            Button {
                onConfirm(mood, goal)
                dismiss()
            } label: {
                HStack(spacing: 7) {
                    Text(L("interpret.confirm"))
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Theme.primary, in: .rect(cornerRadius: 14))
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: seeded)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            guard !seeded else { return }
            mood = interpretation.mood
            goal = interpretation.goal
            seeded = true
        }
    }

    private var moodRow: some View {
        Menu {
            ForEach(Mood.allCases) { option in
                Button {
                    mood = option
                } label: {
                    Text("\(option.emoji) \(option.title)")
                }
            }
        } label: {
            pickerRow(
                label: L("interpret.mood"),
                emoji: mood.emoji,
                title: mood.title,
                tint: mood.tint
            )
        }
    }

    private var goalRow: some View {
        Menu {
            Button {
                goal = nil
            } label: {
                Text(L("interpret.goal.pick"))
            }
            Divider()
            ForEach(ViewingGoal.allCases) { option in
                Button {
                    goal = option
                } label: {
                    Text("\(option.emoji) \(option.title)")
                }
            }
        } label: {
            pickerRow(
                label: L("interpret.goal"),
                emoji: goal?.emoji ?? "🎯",
                title: goal?.title ?? L("interpret.goal.pick"),
                tint: goal?.tint ?? Theme.inkSoft
            )
        }
    }

    private func pickerRow(label: String, emoji: String, title: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Text(emoji)
                .font(.system(size: 24))
                .frame(width: 42, height: 42)
                .background(tint.opacity(0.14), in: .rect(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .textCase(.uppercase)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
            }

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                Text(L("interpret.change"))
                    .font(.caption2.weight(.medium))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(Theme.primary)
        }
        .padding(12)
        .background(Theme.card, in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(tint.opacity(0.2), lineWidth: 1)
        )
        .contentShape(.rect)
    }
}
