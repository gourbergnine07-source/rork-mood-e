//
//  ForcedUpdateView.swift
//  MoodE
//

import SwiftUI

/// Blocking screen shown only when the installed version is below the
/// remotely configured `minimum_required_version` — reserved for real
/// technical breaks (e.g. a retired API), never for new features.
/// There is deliberately no way to dismiss it: the only action is updating.
struct ForcedUpdateView: View {
    @Environment(\.openURL) private var openURL
    @State private var pulse: Bool = false

    private var service: AppUpdateService { .shared }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            RadialGradient(
                colors: [Theme.primary.opacity(0.22), .clear],
                center: .top,
                startRadius: 10,
                endRadius: 420
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 24)

                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(Theme.primary)
                    .scaleEffect(pulse ? 1.06 : 1)
                    .shadow(color: Theme.primary.opacity(0.35), radius: 18, y: 6)
                    .accessibilityHidden(true)

                Text(L("update.required.title"))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .padding(.top, 22)

                Text(service.remoteNote ?? L("update.required.msg"))
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
                    .padding(.horizontal, 8)

                versionRow
                    .padding(.top, 22)

                Spacer(minLength: 24)

                Button {
                    service.logUpdateTap(blocking: true)
                    openURL(service.appStoreURL)
                } label: {
                    Text(L("update.cta"))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Theme.inkInverse)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.primary, in: .capsule)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.impact(weight: .medium), trigger: pulse)

                Text(L("update.required.footer"))
                    .font(.caption2)
                    .foregroundStyle(Theme.inkSoft.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.top, 14)
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 28)
        }
        .task {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        // Swallows any interaction with the app behind the screen.
        .contentShape(.rect)
        .interactiveDismissDisabled()
    }

    private var versionRow: some View {
        HStack(spacing: 10) {
            versionChip(label: L("update.version.installed"), value: service.installedVersion, isCurrent: false)

            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.inkSoft)

            versionChip(label: L("update.version.latest"), value: service.latestVersion, isCurrent: true)
        }
    }

    private func versionChip(label: String, value: String, isCurrent: Bool) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
            Text(value)
                .font(.footnote.weight(.bold))
                .foregroundStyle(isCurrent ? Theme.primary : Theme.inkSoft)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(isCurrent ? Theme.primary.opacity(0.12) : Theme.card, in: .rect(cornerRadius: 12))
    }
}

#Preview {
    ForcedUpdateView()
}
