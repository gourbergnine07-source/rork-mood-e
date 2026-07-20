//
//  PersonalizationView.swift
//  MoodE
//

import SwiftUI

/// "Personalizzazione" screen: every alternate app icon and color theme,
/// with unlock state and the milestone needed for the locked ones.
struct PersonalizationView: View {
    @Environment(PersonalizationStore.self) private var personalization
    private var theme: ThemeManager { ThemeManager.shared }

    var body: some View {
        List {
            iconsSection
            themesSection
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle(L("perso.title"))
        .toolbarTitleDisplayMode(.inline)
    }

    // MARK: - App icons

    private var iconsSection: some View {
        Section {
            ForEach(AppIconOption.allCases) { icon in
                iconRow(icon)
            }
        } header: {
            Text(L("perso.icons.title"))
        } footer: {
            Text(L("perso.icons.footer"))
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
        }
        .listRowBackground(Theme.card)
    }

    private func iconRow(_ icon: AppIconOption) -> some View {
        let unlocked = personalization.isUnlocked(icon)
        let isSelected = personalization.selectedIcon == icon

        return Button {
            personalization.select(icon)
        } label: {
            HStack(spacing: 14) {
                iconPreview(icon, unlocked: unlocked)

                VStack(alignment: .leading, spacing: 2) {
                    Text(icon.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(unlocked ? Theme.ink : Theme.inkSoft)
                    Text(icon.requirement)
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }

                Spacer()

                if isSelected {
                    Label(L("perso.selected"), systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.seenGreen)
                        .labelStyle(.titleAndIcon)
                } else if !unlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft.opacity(0.7))
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
        .sensoryFeedback(.selection, trigger: personalization.selectedIcon)
        .accessibilityLabel("\(icon.title). \(icon.requirement)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func iconPreview(_ icon: AppIconOption, unlocked: Bool) -> some View {
        Image(icon.previewAssetName)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 56, height: 56)
            .clipShape(.rect(cornerRadius: 13))
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .stroke(Theme.ink.opacity(0.08), lineWidth: 1)
            )
            .saturation(unlocked ? 1 : 0)
            .opacity(unlocked ? 1 : 0.45)
            .overlay {
                if !unlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(radius: 3)
                }
            }
            .accessibilityHidden(true)
    }

    // MARK: - Color themes

    private var themesSection: some View {
        Section {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 16) {
                ForEach(AccentPalette.allCases) { palette in
                    themeSwatch(palette)
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text(L("perso.themes.title"))
        } footer: {
            Text(L("perso.themes.footer"))
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
        }
        .listRowBackground(Theme.card)
    }

    private func themeSwatch(_ palette: AccentPalette) -> some View {
        let unlocked = personalization.isUnlocked(palette)
        let isSelected = theme.accent == palette

        return Button {
            guard unlocked else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                theme.accent = palette
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(palette.swatch)
                        .frame(width: 40, height: 40)
                        .saturation(unlocked ? 1 : 0.25)
                        .opacity(unlocked ? 1 : 0.5)

                    if isSelected {
                        Circle()
                            .strokeBorder(palette.swatch, lineWidth: 2.5)
                            .frame(width: 52, height: 52)
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.inkInverse)
                    } else if !unlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                    }
                }
                .frame(width: 52, height: 52)

                Text(palette.displayName)
                    .font(.caption2.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Theme.ink : Theme.inkSoft)

                if !unlocked {
                    Text(personalization.requirement(for: palette))
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.inkSoft.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: theme.accent)
        .accessibilityLabel(unlocked
            ? palette.displayName
            : "\(palette.displayName). \(personalization.requirement(for: palette))")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    NavigationStack {
        PersonalizationView()
    }
    .environment(PersonalizationStore())
}
