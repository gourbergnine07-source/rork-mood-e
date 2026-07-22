//
//  ProfileEditorView.swift
//  MoodE
//

import SwiftUI

/// Profile editor: display name (shown to friends in challenges) and an
/// avatar picked from the predefined set in `ProfileStore`.
struct ProfileEditorView: View {
    @Environment(AuthManager.self) private var auth

    @State private var name: String = ProfileStore.shared.customName
    @State private var avatarHaptic = false
    @State private var showResetConfirm = false
    @State private var resetHaptic = false

    private var profile: ProfileStore { .shared }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 6)

    var body: some View {
        List {
            previewSection
            nameSection
            avatarSection
            resetSection
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle(L("profile.row.title"))
        .toolbarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: avatarHaptic)
        .sensoryFeedback(.success, trigger: resetHaptic)
        .alert(L("profile.reset.title"), isPresented: $showResetConfirm) {
            Button(L("profile.reset.confirm"), role: .destructive) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    profile.reset()
                    name = ""
                }
                resetHaptic.toggle()
            }
            Button(L("common.cancel"), role: .cancel) {}
        } message: {
            Text(L("profile.reset.msg"))
        }
    }

    // MARK: - Live preview

    private var previewSection: some View {
        Section {
            VStack(spacing: 10) {
                Text(profile.avatar)
                    .font(.system(size: 52))
                    .frame(width: 96, height: 96)
                    .background(Theme.primary.opacity(0.12), in: .circle)
                    .overlay(
                        Circle().stroke(Theme.primary.opacity(0.35), lineWidth: 1.5)
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: profile.avatar)

                Text(profile.resolvedName(auth: auth))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.opacity)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    // MARK: - Name

    private var nameSection: some View {
        Section {
            TextField(L("profile.name.placeholder"), text: $name)
                .font(.body)
                .foregroundStyle(Theme.ink)
                .submitLabel(.done)
                .onChange(of: name) { _, newValue in
                    if newValue.count > ProfileStore.maxNameLength {
                        name = String(newValue.prefix(ProfileStore.maxNameLength))
                        return
                    }
                    profile.setName(newValue)
                }
        } header: {
            Text(L("profile.name.label"))
        } footer: {
            Text(L("profile.name.footer"))
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
        }
        .listRowBackground(Theme.card)
    }

    // MARK: - Avatar

    private var avatarSection: some View {
        Section {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(ProfileStore.avatarChoices, id: \.self) { emoji in
                    avatarButton(emoji)
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text(L("profile.avatar.label"))
        } footer: {
            Text(L("profile.footer"))
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
        }
        .listRowBackground(Theme.card)
    }

    // MARK: - Reset

    private var resetSection: some View {
        Section {
            Button(role: .destructive) {
                showResetConfirm = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 15, weight: .semibold))
                    Text(L("profile.reset.button"))
                        .font(.body.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(!profile.isCustomized)
        } footer: {
            Text(L("profile.reset.footer"))
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
        }
        .listRowBackground(Theme.card)
    }

    private func avatarButton(_ emoji: String) -> some View {
        let isSelected = profile.avatar == emoji
        return Button {
            profile.setAvatar(emoji)
            avatarHaptic.toggle()
        } label: {
            Text(emoji)
                .font(.system(size: 26))
                .frame(width: 46, height: 46)
                .background(
                    isSelected ? Theme.primary.opacity(0.18) : Theme.surface.opacity(0.6),
                    in: .circle
                )
                .overlay(
                    Circle().stroke(
                        isSelected ? Theme.primary : Color.clear,
                        lineWidth: 2
                    )
                )
                .scaleEffect(isSelected ? 1.08 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.65), value: isSelected)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(emoji)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    NavigationStack {
        ProfileEditorView()
            .environment(AuthManager())
    }
}
