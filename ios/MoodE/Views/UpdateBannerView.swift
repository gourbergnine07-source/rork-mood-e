//
//  UpdateBannerView.swift
//  MoodE
//

import SwiftUI

/// Discreet, dismissible invite to update, shown at the top of the Home.
/// Never blocks the app: the user can close it with the X and keep going.
/// Driven entirely by the remote release config, so it can be turned on
/// without shipping a build.
struct UpdateBannerView: View {
    @Environment(\.openURL) private var openURL

    private var service: AppUpdateService { .shared }

    /// Remote copy when provided, otherwise the localized default.
    private var message: String {
        service.remoteNote ?? L("update.banner.msg")
    }

    var body: some View {
        HStack(spacing: 12) {
            sparkle

            VStack(alignment: .leading, spacing: 2) {
                Text(L("update.banner.title"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.ink)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                service.logUpdateTap(blocking: false)
                openURL(service.appStoreURL)
            } label: {
                Text(L("update.cta"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.inkInverse)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Theme.primary, in: .capsule)
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    service.dismissBanner()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(width: 28, height: 28)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L("update.banner.dismiss"))
        }
        .padding(.leading, 14)
        .padding(.trailing, 4)
        .padding(.vertical, 10)
        .background(Theme.card, in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Theme.primary.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var sparkle: some View {
        if EmojiSupport.isAvailable {
            Text("🎉")
                .font(.system(size: 20))
        } else {
            Image(systemName: "sparkles")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.amber)
        }
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        UpdateBannerView()
    }
}
