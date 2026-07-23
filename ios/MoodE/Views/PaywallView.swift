//
//  PaywallView.swift
//  MoodE
//

import SwiftUI
import RevenueCat

/// Mood-E Premium paywall: monthly plan, the full feature list and the
/// mandatory restore-purchases action. Reachable only from explicit taps
/// (settings row or a locked feature) — never during the mood flow.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    private var store: PremiumStore { .shared }

    private struct Feature: Identifiable {
        let id: String
        let icon: String
        let tint: Color
    }

    private let features: [Feature] = [
        Feature(id: "noads", icon: "rectangle.slash.fill", tint: Theme.rose),
        Feature(id: "scan", icon: "camera.viewfinder", tint: Theme.seenGreen),
        Feature(id: "duo", icon: "person.2.fill", tint: Theme.tabList),
        Feature(id: "friend", icon: "trophy.fill", tint: Theme.amber),
        Feature(id: "icloud", icon: "icloud.fill", tint: Theme.tabSettings),
        Feature(id: "perso", icon: "paintpalette.fill", tint: Theme.tabTrending),
        Feature(id: "quiz", icon: "theatermasks.fill", tint: Theme.primary),
        Feature(id: "siri", icon: "waveform", tint: Color(red: 0.57, green: 0.42, blue: 0.83))
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        hero
                        featureList
                        Text(L("premium.terms"))
                            .font(.caption2)
                            .foregroundStyle(Theme.inkSoft.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                    .padding(.bottom, 16)
                }
                .scrollIndicators(.hidden)
            }
            .safeAreaInset(edge: .bottom) { ctaBar }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.inkSoft)
                            .frame(width: 30, height: 30)
                            .background(Theme.card, in: .circle)
                    }
                    .accessibilityLabel(L("common.close"))
                }
            }
            .alert(L("common.oops"), isPresented: errorBinding) {
                Button(L("common.ok"), role: .cancel) { store.errorMessage = nil }
            } message: {
                Text(store.errorMessage ?? "")
            }
            .alert(L("premium.restore"), isPresented: restoreBinding) {
                Button(L("common.ok"), role: .cancel) { store.restoreMessage = nil }
            } message: {
                Text(store.restoreMessage ?? "")
            }
            .onChange(of: store.isPremium) { _, isPremium in
                if isPremium { dismiss() }
            }
            .task {
                // Retry automatically: TestFlight/first-launch fetches can
                // fail transiently before StoreKit warms up.
                for attempt in 0..<3 {
                    await store.fetchOfferings()
                    if store.monthlyPackage != nil { return }
                    try? await Task.sleep(for: .seconds(Double(attempt + 1) * 2))
                }
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Theme.amber.opacity(0.35), Theme.rose.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 84, height: 84)
                Image(systemName: "crown.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Theme.amber)
            }
            .padding(.top, 6)

            Text(L("premium.hero"))
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)

            Text(L("premium.sub"))
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Features

    private var featureList: some View {
        VStack(spacing: 10) {
            ForEach(features) { feature in
                HStack(spacing: 12) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(feature.tint)
                        .frame(width: 34, height: 34)
                        .background(feature.tint.opacity(0.14), in: .rect(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(L("premium.feature.\(feature.id)"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        Text(L("premium.feature.\(feature.id).desc"))
                            .font(.caption)
                            .foregroundStyle(Theme.inkSoft)
                    }

                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(Theme.card, in: .rect(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(feature.tint.opacity(0.18), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - CTA

    private var ctaBar: some View {
        VStack(spacing: 8) {
            if store.monthlyPackage == nil && store.offeringsFailed && !store.isLoading {
                VStack(spacing: 4) {
                    Text(L("premium.load.failed"))
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.center)
                    Button {
                        Task { await store.fetchOfferings() }
                    } label: {
                        Text(L("premium.load.retry"))
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(Theme.amber)
                    }
                }
                .padding(.bottom, 2)
            }

            Button {
                Task { await store.purchase() }
            } label: {
                HStack(spacing: 8) {
                    if store.isPurchasing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    Text(ctaTitle)
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        colors: [Theme.amber, Theme.rose],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: .rect(cornerRadius: 16)
                )
            }
            .disabled(store.isPurchasing || store.monthlyPackage == nil)
            .sensoryFeedback(.impact(weight: .medium), trigger: store.isPurchasing)

            Button {
                Task { await store.restore() }
            } label: {
                Text(L("premium.restore"))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
            .disabled(store.isPurchasing)
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(.ultraThinMaterial)
    }

    private var ctaTitle: String {
        if let price = store.monthlyPackage?.storeProduct.localizedPriceString {
            return LF("premium.cta", price)
        }
        if store.offeringsFailed && !store.isLoading {
            return L("premium.cta.unavailable")
        }
        return L("premium.cta.loading")
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )
    }

    private var restoreBinding: Binding<Bool> {
        Binding(
            get: { store.restoreMessage != nil },
            set: { if !$0 { store.restoreMessage = nil } }
        )
    }
}

#Preview {
    PaywallView()
}
