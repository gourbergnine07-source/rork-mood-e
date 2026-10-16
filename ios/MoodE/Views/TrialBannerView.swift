//
//  TrialBannerView.swift
//  MoodE
//

import SwiftUI

/// One-time, discreet Home banner inviting to start the free trial, shown
/// the day after first use — a value moment, never at launch. Tapping opens
/// the paywall; the X makes it disappear forever.
struct TrialBannerView: View {
    @State private var showPaywall: Bool = false
    private var coordinator: PaywallCoordinator { .shared }
    private var store: PremiumStore { .shared }

    /// Duration comes from the store when loaded; honest generic fallback.
    private var subtitle: String {
        if let offer = store.trialOffer {
            return LF("home.trial.sub", offer.durationText)
        }
        return L("home.trial.sub.generic")
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.amber)
                .frame(width: 38, height: 38)
                .background(Theme.amber.opacity(0.15), in: .circle)

            VStack(alignment: .leading, spacing: 2) {
                Text(L("home.trial.title"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                coordinator.finishDayAfterBanner()
                showPaywall = true
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
                coordinator.finishDayAfterBanner()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(width: 28, height: 28)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L("common.close"))
        }
        .padding(.leading, 14)
        .padding(.trailing, 4)
        .padding(.vertical, 10)
        .background(Theme.card, in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Theme.amber.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
        .sheet(isPresented: $showPaywall) {
            PaywallView(origin: .dayAfterBanner)
        }
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
    }
    .safeAreaInset(edge: .top) {
        TrialBannerView()
    }
}
