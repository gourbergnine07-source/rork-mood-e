//
//  PaywallView.swift
//  MoodE
//

import SwiftUI
import RevenueCat

/// Mood-E Premium paywall: monthly and annual plans, the full feature list
/// and the mandatory restore-purchases action. Reachable only from explicit
/// taps (settings row or a locked feature) — never during the mood flow.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    private var store: PremiumStore { .shared }

    /// Where the paywall was opened from — sent with the analytics events
    /// and used by PaywallCoordinator's throttling rules.
    var origin: PaywallCoordinator.Origin = .lockedFeature

    /// Which plan the CTA purchases. Annual is preselected as the
    /// recommended option whenever the offering includes it.
    private enum PlanPeriod {
        case monthly
        case annual
    }

    /// Path for the legal pages: lets onDisappear tell a real dismissal
    /// (paywall closed) apart from just opening Terms/Privacy.
    @State private var legalPath = NavigationPath()
    @State private var selectedPeriod: PlanPeriod = .annual

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
        NavigationStack(path: $legalPath) {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        hero
                        planCards
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
                    if store.hasPlans { return }
                    try? await Task.sleep(for: .seconds(Double(attempt + 1) * 2))
                }
            }
            .onAppear { PaywallCoordinator.shared.noteShown(origin: origin) }
            .onDisappear {
                // Opening Terms/Privacy pushes a legal page: only a close
                // with an empty stack counts as "user dismissed the paywall".
                if legalPath.isEmpty {
                    PaywallCoordinator.shared.noteDismissed(origin: origin)
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

    /// Title, duration and price shown before purchase, as required for
    /// auto-renewable subscriptions. Two selectable cards; the annual one
    /// carries the savings badge. Prices always come from StoreKit — never
    /// hardcoded — so ASC price changes reflect automatically.
    private var planCards: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("premium.plan.header"))
                .font(.caption2.weight(.bold))
                .foregroundStyle(Theme.amber)
                .textCase(.uppercase)

            if let annual = store.annualPackage {
                planCard(
                    for: annual,
                    period: .annual,
                    badge: store.trialOffer.map { LF("premium.trial.badge", $0.durationText) }
                        ?? L("premium.plan.badge.annual"),
                    highlight: bestValueText
                )
            }

            if let monthly = store.monthlyPackage {
                planCard(
                    for: monthly,
                    period: .monthly,
                    badge: L("premium.plan.badge"),
                    highlight: nil
                )
            }
        }
    }

    /// Falls back to monthly when the offering has no annual package yet.
    private var effectivePeriod: PlanPeriod {
        store.annualPackage == nil ? .monthly : selectedPeriod
    }

    /// The package the CTA will purchase.
    private var selectedPackage: Package? {
        effectivePeriod == .annual ? store.annualPackage : store.monthlyPackage
    }

    /// "Best value · Save 50%", with the percentage computed live from the
    /// two StoreKit prices (1 − annual / (monthly × 12)).
    private var bestValueText: String? {
        guard store.monthlyPackage != nil else { return nil }
        guard let savings = savingsPercent else { return L("premium.plan.best") }
        return "\(L("premium.plan.best")) · \(LF("premium.plan.save", savings))"
    }

    private var savingsPercent: Int? {
        guard let monthly = store.monthlyPackage?.storeProduct.price,
              let annual = store.annualPackage?.storeProduct.price else { return nil }
        let monthlyDouble = NSDecimalNumber(decimal: monthly).doubleValue
        let annualDouble = NSDecimalNumber(decimal: annual).doubleValue
        let fullYear = monthlyDouble * 12
        guard fullYear > 0, annualDouble < fullYear else { return nil }
        return Int(((1 - annualDouble / fullYear) * 100).rounded())
    }

    private func planCard(
        for package: Package,
        period: PlanPeriod,
        badge: String,
        highlight: String?
    ) -> some View {
        let isSelected = effectivePeriod == period
        let product = package.storeProduct
        // Free trial: show what comes after it instead of the monthly
        // equivalent — both prices always come from the store.
        let thenPrice = period == .annual
            ? store.trialOffer.map { LF("premium.trial.thenPrice", $0.annualPriceString) }
            : nil
        return Button {
            AnalyticsService.shared.log("paywall_plan_tapped", meta: [
                "plan": period == .annual ? "annual" : "monthly"
            ])
            withAnimation(.snappy) { selectedPeriod = period }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(badge)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Theme.inkSoft)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.inkSoft.opacity(0.1), in: .capsule)

                    if let highlight {
                        Text(highlight)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Theme.amber, in: .capsule)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(isSelected ? Theme.amber : Theme.inkSoft.opacity(0.4))
                }

                Text(product.localizedTitle)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(product.localizedPriceString)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText())
                    Text(period == .annual ? L("premium.plan.perYear") : L("premium.plan.perMonth"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.inkSoft)
                }

                if period == .annual, let thenPrice {
                    Text(thenPrice)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.seenGreen)
                } else if period == .annual, let perMonth = product.localizedPricePerMonth {
                    Text(LF("premium.plan.perMonthEquiv", perMonth))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.seenGreen)
                }

                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11, weight: .semibold))
                    Text(period == .annual ? L("premium.plan.duration.annual") : L("premium.plan.duration"))
                        .font(.caption)
                }
                .foregroundStyle(Theme.inkSoft)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: .rect(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? Theme.amber : Theme.amber.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - Legal (guideline 3.1.2(c): functional EULA + privacy links)

    private var legalBlock: some View {
        VStack(spacing: 12) {
            if let offer = store.trialOffer {
                Text(LF("premium.trial.legal", offer.durationText, offer.annualPriceString))
                    .font(.caption2)
                    .foregroundStyle(Theme.inkSoft.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
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
            if !store.hasPlans && store.offeringsFailed && !store.isLoading {
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
                Task { await store.purchase(selectedPackage) }
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
            .disabled(store.isPurchasing || selectedPackage == nil)
            .sensoryFeedback(.impact(weight: .medium), trigger: store.isPurchasing)
            .sensoryFeedback(.selection, trigger: effectivePeriod)

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
        if store.trialOffer != nil, effectivePeriod == .annual {
            return L("premium.cta.trial")
        }
        if let price = selectedPackage?.storeProduct.localizedPriceString {
            return effectivePeriod == .annual
                ? LF("premium.cta.annual", price)
                : LF("premium.cta", price)
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
