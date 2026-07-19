//
//  AdviceComposerView.swift
//  MoodE
//

import SwiftUI

/// Sheet to publish a new anonymous advice request:
/// pick one of the 12 emotions, write up to 200 characters, publish.
struct AdviceComposerView: View {
    var onPublished: (AdviceRequest) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(MoodDiary.self) private var diary

    @State private var selectedMood: Mood?
    @State private var text: String = ""
    @State private var isPublishing: Bool = false
    @State private var errorMessage: String?
    @FocusState private var textFocused: Bool

    private var community: CommunityService { CommunityService.shared }
    private let maxLength = 200

    private let moodColumns: [GridItem] = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(L("advice.composer.moodLabel"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.ink)

                        LazyVGrid(columns: moodColumns, spacing: 8) {
                            ForEach(Mood.allCases) { mood in
                                moodChip(mood)
                            }
                        }

                        textEditor

                        if let errorMessage {
                            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                                .font(.footnote)
                                .foregroundStyle(Theme.rose)
                        }

                        Text(LF("advice.composer.anon", community.nickname))
                            .font(.caption)
                            .foregroundStyle(Theme.inkSoft)

                        publishButton
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(L("advice.composer.title"))
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("common.cancel")) { dismiss() }
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Pieces

    private func moodChip(_ mood: Mood) -> some View {
        Button {
            selectedMood = mood
        } label: {
            VStack(spacing: 4) {
                if EmojiSupport.isAvailable {
                    Text(mood.emoji).font(.system(size: 20))
                } else {
                    Image(systemName: mood.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(mood.tint)
                        .frame(height: 24)
                }
                Text(mood.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                selectedMood == mood ? mood.tint.opacity(0.30) : mood.tint.opacity(0.10),
                in: .rect(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        selectedMood == mood ? mood.tint : mood.tint.opacity(0.2),
                        lineWidth: selectedMood == mood ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(PressableCardStyle())
        .sensoryFeedback(.selection, trigger: selectedMood == mood)
    }

    private var textEditor: some View {
        VStack(alignment: .trailing, spacing: 4) {
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(L("advice.composer.placeholder"))
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft.opacity(0.6))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                }
                TextEditor(text: $text)
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                    .focused($textFocused)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 110)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .onChange(of: text) { _, newValue in
                        if newValue.count > maxLength {
                            text = String(newValue.prefix(maxLength))
                        }
                    }
            }
            .background(Theme.card, in: .rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.tabTrending.opacity(0.2), lineWidth: 1)
            )

            Text("\(text.count)/\(maxLength)")
                .font(.caption2)
                .foregroundStyle(text.count >= maxLength ? Theme.rose : Theme.inkSoft)
                .monospacedDigit()
        }
    }

    private var publishButton: some View {
        Button {
            publish()
        } label: {
            HStack(spacing: 8) {
                if isPublishing {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(L("advice.composer.publish"))
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(
                canPublish ? Theme.tabTrending : Theme.tabTrending.opacity(0.35),
                in: .rect(cornerRadius: 14)
            )
        }
        .disabled(isPublishing)
        .sensoryFeedback(.success, trigger: isPublishing)
    }

    // MARK: - Logic

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canPublish: Bool {
        selectedMood != nil && !trimmedText.isEmpty
    }

    private func publish() {
        textFocused = false
        guard let mood = selectedMood else {
            errorMessage = L("advice.composer.needMood")
            return
        }
        guard !trimmedText.isEmpty else {
            errorMessage = L("advice.composer.needText")
            return
        }
        errorMessage = nil
        isPublishing = true
        Task {
            defer { isPublishing = false }
            do {
                let request = try await community.publishRequest(mood: mood, text: trimmedText)
                diary.recordCommunityAction()
                onPublished(request)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
