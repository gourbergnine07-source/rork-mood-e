//
//  PremiumUpsellRow.swift
//  MoodE
//

import SwiftUI

/// Small, quiet line pointing to the paywall: "Vuoi meno pubblicità?
/// Passa a Premium". Shown in Settings (ads section) and at the bottom of
/// the results list — never on top of an ad.
struct PremiumUpsellRow: View {
    /// Localized line to show — context-dependent (ads, limited bonuses…).
    var messageKey: String = "ads.upsell"
    /// Analytics origin for the paywall opening.
    var origin: PaywallCoordinator.Origin = .removeAds
    @State private var showPaywall = false

    var body: some View {
        Button { showPaywall = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.amber)
                Text(L(messageKey))
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.leading)
                    .underline()
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPaywall) {
            PaywallView(origin: origin)
        }
    }
}

#Preview {
    VStack {
        PremiumUpsellRow()
    }
    .background(Theme.background)
}
