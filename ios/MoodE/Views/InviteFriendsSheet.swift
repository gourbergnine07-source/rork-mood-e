//
//  InviteFriendsSheet.swift
//  MoodE
//

import SwiftUI

/// "Invite friends" sheet: fetches (or creates) the personal friend code
/// and shares the unique invite link through the system share sheet.
struct InviteFriendsSheet: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var code: String?
    @State private var isLoading = false
    @State private var failed = false
    @State private var didCopy = false
    @State private var showAccountSheet = false

    private let service = FriendStatsService.shared

    private var displayName: String {
        ProfileStore.shared.resolvedName(auth: auth)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                content
                    .padding(.horizontal, 24)
            }
            .navigationTitle(L("invite.title"))
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
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
        .presentationDetents([.medium, .large])
        .sheet(isPresented: $showAccountSheet) {
            AccountSheetView()
        }
        .sensoryFeedback(.success, trigger: didCopy)
        .task { await load() }
        .onChange(of: auth.user?.id) { _, newValue in
            if newValue != nil {
                Task { await load() }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if auth.user == nil {
            signedOutState
        } else if let code {
            loadedState(code: code)
        } else if failed {
            errorState
        } else {
            ProgressView()
        }
    }

    // MARK: - Loaded

    private func loadedState(code: String) -> some View {
        VStack(spacing: 18) {
            Text("🎟️")
                .font(.system(size: 52))

            Text(L("invite.msg"))
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            VStack(spacing: 4) {
                Text(L("friends.mycode.title"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.inkSoft)
                Text(code)
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.primary)
                    .kerning(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.card, in: .rect(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Theme.primary.opacity(0.18), lineWidth: 1)
            )

            ShareLink(item: InviteLink.shareMessage(code: code)) {
                Label(L("invite.share.button"), systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Theme.primary, in: .rect(cornerRadius: 14))
                    .contentShape(.rect)
            }
            .buttonStyle(PressableCardStyle())

            if let url = InviteLink.url(code: code) {
                Button {
                    UIPasteboard.general.string = url.absoluteString
                    didCopy = true
                } label: {
                    Label(
                        didCopy ? L("invite.copied") : L("invite.copy"),
                        systemImage: didCopy ? "checkmark" : "doc.on.doc"
                    )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(didCopy ? Theme.seenGreen : Theme.primary)
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.2), value: didCopy)
            }
        }
    }

    // MARK: - Signed out

    private var signedOutState: some View {
        VStack(spacing: 14) {
            Text("🏆")
                .font(.system(size: 52))

            Text(L("friends.signin.title"))
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)

            Text(L("friends.signin.msg"))
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            Button {
                showAccountSheet = true
            } label: {
                Text(L("friends.signin.button"))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Theme.primary, in: .rect(cornerRadius: 14))
                    .contentShape(.rect)
            }
            .buttonStyle(PressableCardStyle())
            .padding(.top, 4)
        }
    }

    // MARK: - Error

    private var errorState: some View {
        VStack(spacing: 14) {
            Text("📡")
                .font(.system(size: 44))

            Text(L("invite.error"))
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)

            Button {
                Task { await load() }
            } label: {
                Text(L("common.retry"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.primary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Theme.primary.opacity(0.12), in: .capsule)
                    .contentShape(.capsule)
            }
            .buttonStyle(.plain)
        }
    }

    private func load() async {
        guard auth.user != nil, code == nil, !isLoading else { return }
        isLoading = true
        failed = false
        defer { isLoading = false }

        code = await service.ensureCode(auth: auth, displayName: displayName)
        failed = code == nil
        if code != nil {
            AnalyticsService.shared.log("invite_link_generated")
        }
    }
}

#Preview {
    InviteFriendsSheet()
        .environment(AuthManager())
}
