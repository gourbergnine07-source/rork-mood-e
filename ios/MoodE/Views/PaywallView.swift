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
        Feature(id: "siri", icon: "waveform", tint: Color(red: 0.57, green: 0.42, blue: 0.83)),
        Feature(id: "tv", icon: "tv.fill", tint: Theme.tabCinema)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        hero
                        planCard
                        featureList
                        legalBlock
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                    .padding(.bottom, 16)
                }
                .scrollIndicators(.hidden)
            }
            .safeAreaInset(edge: .bottom) { ctaBar }
            .navigationDestination(for: LegalPage.self) { page in
                LegalPageView(page: page)
            }
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

    // MARK: - Plan details (App Store guideline 3.1.2)

    /// Subscription title, duration and price shown before purchase, as
    /// required for auto-renewable subscriptions.
    private var planCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(L("premium.plan.header"))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.amber)
                    .textCase(.uppercase)
                Spacer(minLength: 0)
                Text(L("premium.plan.badge"))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.amber, in: .capsule)
            }

            Text(planTitle)
                .font(.headline)
                .foregroundStyle(Theme.ink)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(planPrice)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                Text(L("premium.plan.perMonth"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.inkSoft)
            }

            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11, weight: .semibold))
                Text(L("premium.plan.duration"))
                    .font(.caption)
            }
            .foregroundStyle(Theme.inkSoft)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: .rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Theme.amber.opacity(0.35), lineWidth: 1)
        )
    }

    private var planTitle: String {
        store.monthlyPackage?.storeProduct.localizedTitle ?? L("premium.plan.title")
    }

    private var planPrice: String {
        store.monthlyPackage?.storeProduct.localizedPriceString ?? "—"
    }

    // MARK: - Legal (guideline 3.1.2(c): functional EULA + privacy links)

    private var legalBlock: some View {
        VStack(spacing: 12) {
            Text(L("premium.terms"))
                .font(.caption2)
                .foregroundStyle(Theme.inkSoft.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            HStack(spacing: 10) {
                legalLink(page: .terms, icon: "doc.text.fill", title: L("premium.legal.eula"))
                legalLink(page: .privacyPolicy, icon: "hand.raised.fill", title: L("legal.privacy"))
            }
        }
    }

    private func legalLink(page: LegalPage, icon: String, title: String) -> some View {
        NavigationLink(value: page) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(Theme.tabSettings)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .padding(.horizontal, 10)
            .background(Theme.card, in: .rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.tabSettings.opacity(0.28), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
                // Distinct alert card so the plan-loading error can't be
                // mistaken for the feature cards scrolling underneath
                // (e.g. the iCloud sync one).
                HStack(spacing: 10) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.amber)

                    Text(L("premium.load.failed"))
                        .font(.caption)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        Task { await store.fetchOfferings() }
                    } label: {
                        Text(L("premium.load.retry"))
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(Theme.amber)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Theme.amber.opacity(0.14), in: .capsule)
                    }
                }
                .padding(10)
                .background(Theme.card, in: .rect(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Theme.amber.opacity(0.35), lineWidth: 1)
                )
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
        .background(Theme.background.opacity(0.92))
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
