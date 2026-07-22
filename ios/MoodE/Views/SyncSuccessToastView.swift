//
//  SyncSuccessToastView.swift
//  MoodE
//

import SwiftUI

/// Discreet confirmation pill shown when an iCloud sync completes
/// successfully with no merge conflict. Small, quiet and short-lived —
/// the opposite of the celebratory `UnlockToastView`.
struct SyncSuccessToastView: View {
    @State private var appeared: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.icloud.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.seenGreen)
                .symbolEffect(.bounce, value: appeared)

            Text(L("icloud.success.toast"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Theme.cardStrong, in: .capsule)
        .overlay(
            Capsule().stroke(Theme.seenGreen.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        .padding(.top, 6)
        .scaleEffect(appeared ? 1 : 0.9)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                appeared = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L("icloud.success.toast"))
    }
}

#Preview {
    SyncSuccessToastView()
        .padding()
        .background(Theme.background)
}
