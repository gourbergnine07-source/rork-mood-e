//
//  AccountSheetView.swift
//  MoodE
//

import SwiftUI
import AuthenticationServices

/// Sign-in sheet for the optional cloud backup: explains what gets synced
/// and offers Apple / Google sign-in via Rork Auth.
struct AccountSheetView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        @Bindable var auth = auth

        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "icloud.and.arrow.up.fill")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(Theme.tabSettings)
                        .padding(.top, 28)

                    Text(L("account.sheet.title"))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)

                    Text(L("account.sheet.msg"))
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 12) {
                        syncItem(icon: "book.closed.fill", color: Theme.rose, text: L("account.sync.diary"))
                        syncItem(icon: "bookmark.fill", color: Theme.primary, text: L("account.sync.list"))
                        syncItem(icon: "calendar", color: Theme.tabCinema, text: L("account.sync.planner"))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Theme.card, in: .rect(cornerRadius: 18))

                    Text(L("account.privacy"))
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: 10) {
                if auth.isSigningIn {
                    ProgressView()
                        .padding(.bottom, 4)
                }

                SignInWithAppleButton(.continue) { request in
                    request.requestedScopes = [.email, .fullName]
                } onCompletion: { _ in
                    Task { await signIn(provider: "apple") }
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 50)
                .clipShape(.rect(cornerRadius: 14))
                .disabled(auth.isSigningIn)

                Button {
                    Task { await signIn(provider: "google") }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "globe")
                            .font(.system(size: 15, weight: .semibold))
                        Text(L("account.google"))
                            .font(.body.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .foregroundStyle(Theme.ink)
                    .background(Theme.card, in: .rect(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Theme.ink.opacity(0.15), lineWidth: 1)
                    )
                }
                .disabled(auth.isSigningIn)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .background(Theme.background)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .alert(L("account.error.title"), isPresented: $auth.showError) {
            Button("OK") { }
        } message: {
            Text(auth.errorMessage)
        }
    }

    private func syncItem(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(color, in: .rect(cornerRadius: 7))
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 0)
            Image(systemName: "checkmark.icloud.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.seenGreen)
        }
    }

    private func signIn(provider: String) async {
        await auth.signIn(provider: provider)
        guard auth.user != nil else { return }
        dismiss()
        await CloudSyncService.shared.syncNow()
    }
}
