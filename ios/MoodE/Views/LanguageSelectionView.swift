//
//  LanguageSelectionView.swift
//  MoodE
//

import SwiftUI

/// First-launch language picker: the detected system language is preselected,
/// the user can confirm or change it before onboarding (and before the ATT prompt).
struct LanguageSelectionView: View {
    let onFinished: () -> Void

    @State private var selected: AppLanguage = LocalizationManager.shared.language

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Theme.primary.opacity(0.10))
                        .frame(width: 150, height: 150)
                    Circle()
                        .fill(Theme.primary.opacity(0.14))
                        .frame(width: 116, height: 116)
                    Image(systemName: "globe")
                        .font(.system(size: 52))
                        .foregroundStyle(Theme.primary)
                }
                .padding(.bottom, 26)

                VStack(spacing: 8) {
                    Text(localized("lang.title"))
                        .font(.title.weight(.bold))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)

                    Text(localized("lang.subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 28)

                VStack(spacing: 10) {
                    ForEach(AppLanguage.allCases) { language in
                        languageRow(language)
                    }
                }
                .padding(.horizontal, 28)

                Spacer()

                Button {
                    LocalizationManager.shared.language = selected
                    LocalizationManager.shared.hasChosenLanguage = true
                    onFinished()
                } label: {
                    HStack(spacing: 8) {
                        Text(localized("lang.continue"))
                            .font(.headline)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Theme.primary, in: .rect(cornerRadius: 18))
                    .shadow(color: Theme.primary.opacity(0.35), radius: 10, y: 5)
                }
                .buttonStyle(PressableCardStyle())
                .padding(.horizontal, 28)
                .padding(.bottom, 36)
            }
        }
        .sensoryFeedback(.selection, trigger: selected)
    }

    /// Strings shown in the currently highlighted language, so the
    /// screen updates live while the user explores the options.
    private func localized(_ key: String) -> String {
        L10nStore.string(key, language: selected.rawValue)
    }

    private func languageRow(_ language: AppLanguage) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                selected = language
            }
        } label: {
            HStack(spacing: 14) {
                if EmojiSupport.isAvailable {
                    Text(language.flag)
                        .font(.system(size: 30))
                } else {
                    Text(language.rawValue.uppercased())
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.primary)
                        .frame(width: 44, height: 30)
                        .background(Theme.primary.opacity(0.12), in: .rect(cornerRadius: 8))
                }

                Text(language.nativeName)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)

                Spacer()

                Image(systemName: selected == language ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(selected == language ? Theme.primary : Theme.inkSoft.opacity(0.35))
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(.horizontal, 16)
            .frame(height: 60)
            .background(Theme.card, in: .rect(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        selected == language ? Theme.primary.opacity(0.6) : Theme.primary.opacity(0.10),
                        lineWidth: selected == language ? 1.5 : 1
                    )
            )
            .contentShape(.rect)
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityLabel(language.nativeName)
        .accessibilityAddTraits(selected == language ? .isSelected : [])
    }
}

#Preview {
    LanguageSelectionView(onFinished: {})
}
