//
//  ProfileEditorView.swift
//  MoodE
//

import SwiftUI
import PhotosUI

/// Profile editor: display name (shown to friends in challenges) and an
/// avatar picked from the predefined set in `ProfileStore`.
struct ProfileEditorView: View {
    @Environment(AuthManager.self) private var auth

    @State private var name: String = ProfileStore.shared.customName
    @State private var avatarHaptic = false
    @State private var showResetConfirm = false
    @State private var resetHaptic = false
    @State private var syncState: ProfileSyncState = .idle
    @State private var pushTask: Task<Void, Never>?
    @State private var photoItem: PhotosPickerItem?

    private var profile: ProfileStore { .shared }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 6)

    var body: some View {
        List {
            previewSection
            nameSection
            photoSection
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
                scheduleBackendPush(immediate: true)
            }
            Button(L("common.cancel"), role: .cancel) {}
        } message: {
            Text(L("profile.reset.msg"))
        }
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        profile.setPhoto(data)
                    }
                    avatarHaptic.toggle()
                }
                photoItem = nil
            }
        }
    }

    // MARK: - Live preview

    private var previewSection: some View {
        Section {
            VStack(spacing: 10) {
                previewAvatar
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: profile.avatar)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: profile.photoData)

                Text(profile.resolvedName(auth: auth))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.opacity)

                syncIndicator
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    /// Big round preview: the user's own photo when set, the emoji
    /// avatar otherwise.
    @ViewBuilder
    private var previewAvatar: some View {
        if let data = profile.photoData, let image = UIImage(data: data) {
            Color(Theme.surface)
                .frame(width: 96, height: 96)
                .overlay {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .allowsHitTesting(false)
                }
                .clipShape(.circle)
                .overlay(
                    Circle().stroke(Theme.primary.opacity(0.35), lineWidth: 1.5)
                )
        } else {
            Text(profile.avatar)
                .font(.system(size: 52))
                .frame(width: 96, height: 96)
                .background(Theme.primary.opacity(0.12), in: .circle)
                .overlay(
                    Circle().stroke(Theme.primary.opacity(0.35), lineWidth: 1.5)
                )
        }
    }

    /// Discreet real-time save status: visible only for signed-in users,
    /// whose profile is pushed to the backend as they edit.
    @ViewBuilder
    private var syncIndicator: some View {
        if auth.user != nil {
            HStack(spacing: 5) {
                switch syncState {
                case .idle:
                    EmptyView()
                case .saving:
                    ProgressView()
                        .controlSize(.mini)
                    Text(L("profile.sync.saving"))
                        .foregroundStyle(Theme.inkSoft)
                case .saved:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.seenGreen)
                    Text(L("profile.sync.saved"))
                        .foregroundStyle(Theme.seenGreen)
                }
            }
            .font(.caption2.weight(.semibold))
            .frame(height: 14)
            .animation(.easeInOut(duration: 0.2), value: syncState)
        }
    }

    /// Debounced push of name + avatar to the cloud so friends see the
    /// update in real time. No-op when signed out (local-only profile).
    private func scheduleBackendPush(immediate: Bool = false) {
        guard auth.user != nil else { return }
        pushTask?.cancel()
        syncState = .saving
        pushTask = Task {
            if !immediate {
                try? await Task.sleep(for: .seconds(1))
            }
            guard !Task.isCancelled else { return }
            let ok = await FriendStatsService.shared.pushProfile(
                auth: auth,
                displayName: profile.resolvedName(auth: auth),
                avatar: profile.avatar
            )
            guard !Task.isCancelled else { return }
            syncState = ok ? .saved : .idle
        }
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
                    scheduleBackendPush()
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

    // MARK: - Photo

    private var photoSection: some View {
        Section {
            PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                HStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                        .frame(width: 24)
                    Text(L("profile.photo.choose"))
                        .font(.body)
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft.opacity(0.6))
                }
                .contentShape(.rect)
            }

            if profile.photoData != nil {
                Button(role: .destructive) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        profile.removePhoto()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 24)
                        Text(L("profile.photo.remove"))
                            .font(.body)
                    }
                }
            }
        } header: {
            Text(L("profile.photo.label"))
        } footer: {
            Text(L("profile.photo.footer"))
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
        let isSelected = profile.avatar == emoji && profile.photoData == nil
        return Button {
            profile.setAvatar(emoji)
            avatarHaptic.toggle()
            scheduleBackendPush()
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

/// Save states of the real-time backend push.
private enum ProfileSyncState {
    case idle
    case saving
    case saved
}

#Preview {
    NavigationStack {
        ProfileEditorView()
            .environment(AuthManager())
    }
}
