//
//  PremiumStore.swift
//  MoodE
//

import Foundation
import Observation
import RevenueCat
import UserNotifications

/// Free-trial offer on the annual plan, read from StoreKit — never
/// hardcoded. Nil when the plan has no intro offer or the user is not
/// eligible (trial already used): the paywall then shows regular pricing.
struct TrialOfferInfo {
    /// Localized duration, e.g. "7 giorni" — built from the store's period.
    let durationText: String
    /// Localized annual price that starts after the trial.
    let annualPriceString: String
}

/// Central subscription state (RevenueCat). Premium is tied to the Apple ID
/// via In-App Purchase — no Mood-E account needed. The active flag is also
/// cached in UserDefaults so ad gating and App Intents can read it
/// synchronously at launch.
@Observable
final class PremiumStore {
    static let shared = PremiumStore()

    /// Cached premium flag, readable without waiting for the network.
    static let cacheKey = "premium.active"

    private(set) var isPremium: Bool
    private(set) var offerings: Offerings?
    private(set) var isLoading: Bool = false
    /// True when the last offerings fetch failed or returned no plan —
    /// lets the paywall show a retry action instead of loading forever.
    private(set) var offeringsFailed: Bool = false
    var isPurchasing: Bool = false
    var errorMessage: String?
    /// One-shot feedback after "Ripristina acquisti".
    var restoreMessage: String?
    /// Annual-plan free trial, when the user can claim it.
    private(set) var trialOffer: TrialOfferInfo?

    private static let trialActiveKey = "premium.trialActive"
    private static let trialReminderId = "trial_end_reminder"

    private init() {
        isPremium = UserDefaults.standard.bool(forKey: Self.cacheKey)
    }

    /// Synchronous check for early-launch paths (ads, App Intents).
    static var isPremiumCached: Bool {
        UserDefaults.standard.bool(forKey: cacheKey)
    }

    /// RevenueCat public SDK keys — safe to embed in the client per RevenueCat docs.
    private static let testStoreAPIKey = "test_xHUcAbpypOmJUQRftSASqkDasoy"
    private static let appStoreAPIKey = "appl_fGUqgkWlxLExECTerLeAAmrjnzG"

    /// Must be called once from the App's `init()`, before any other use.
    static func configureSDK() {
        #if DEBUG
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: testStoreAPIKey)
        #else
        Purchases.configure(withAPIKey: appStoreAPIKey)
        #endif
    }

    /// Begins listening for entitlement changes and loads the offering.
    func start() {
        Task { await listenForUpdates() }
        Task { await fetchOfferings() }
    }

    /// The monthly plan shown on the paywall.
    var monthlyPackage: Package? {
        offerings?.current?.monthly
            ?? offerings?.current?.availablePackages.first(where: { $0.packageType == .monthly })
    }

    /// The annual plan (second paywall option). Nil while the RevenueCat
    /// offering doesn't include it yet — the paywall then falls back to
    /// the monthly-only layout.
    var annualPackage: Package? {
        offerings?.current?.annual
            ?? offerings?.current?.availablePackages.first(where: { $0.packageType == .annual })
    }

    /// True when at least one plan loaded from RevenueCat.
    var hasPlans: Bool {
        monthlyPackage != nil || annualPackage != nil
    }

    private func listenForUpdates() async {
        for await info in Purchases.shared.customerInfoStream {
            apply(info)
        }
    }

    /// One-time refresh (e.g. at launch, before deciding whether to load ads).
    func refreshStatus() async {
        do {
            apply(try await Purchases.shared.customerInfo())
        } catch {
            print("PremiumStore: status refresh failed: \(error.localizedDescription)")
        }
    }

    func fetchOfferings() async {
        guard !isLoading else { return }
        isLoading = true
        offeringsFailed = false
        do {
            offerings = try await Purchases.shared.offerings()
            if !hasPlans {
                // Fetch succeeded but no plan came back (e.g. product not
                // yet purchasable on this storefront) — keep it retryable.
                offeringsFailed = true
                print("PremiumStore: offerings loaded but no subscription package")
            } else {
                await refreshTrialOffer()
            }
        } catch {
            offeringsFailed = true
            print("PremiumStore: offerings failed: \(error.localizedDescription)")
        }
        isLoading = false
    }

    /// Reads the annual plan's free trial from StoreKit (duration and the
    /// price that follows) and checks whether this user may claim it.
    /// Apple allows one intro offer per subscription group: users who
    /// already used it see regular pricing instead.
    private func refreshTrialOffer() async {
        guard let annual = annualPackage,
              let intro = annual.storeProduct.introductoryDiscount,
              intro.paymentMode == .freeTrial else {
            trialOffer = nil
            return
        }
        let eligibilities = await Purchases.shared.checkTrialOrIntroDiscountEligibility(
            productIdentifiers: [annual.storeProduct.productIdentifier])
        guard eligibilities[annual.storeProduct.productIdentifier]?.status == .eligible else {
            trialOffer = nil
            return
        }
        trialOffer = TrialOfferInfo(
            durationText: Self.trialDurationText(intro),
            annualPriceString: annual.storeProduct.localizedPriceString
        )
    }

    private static func trialDurationText(_ discount: StoreProductDiscount) -> String {
        let period = discount.subscriptionPeriod
        switch period.unit {
        case .day: return LF("premium.trial.unit.day", period.value)
        case .week: return LF("premium.trial.unit.week", period.value)
        case .month: return LF("premium.trial.unit.month", period.value)
        case .year: return LF("premium.trial.unit.year", period.value)
        default: return LF("premium.trial.unit.day", period.value)
        }
    }

    /// Purchases the given package; defaults to the monthly plan.
    func purchase(_ package: Package? = nil) async {
        guard let package = package ?? monthlyPackage, !isPurchasing else { return }
        isPurchasing = true
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if !result.userCancelled {
                apply(result.customerInfo)
                // RevenueCat applies the intro offer automatically when the
                // user is eligible — the transaction decides the wording.
                let startedWithTrial = result.customerInfo.entitlements["premium"]?.periodType == .trial
                AnalyticsService.shared.log(startedWithTrial ? "trial_started" : "premium_purchased")
                PaywallCoordinator.shared.markConverted()
            }
        } catch ErrorCode.purchaseCancelledError {
            // User closed the sheet — not an error.
        } catch ErrorCode.paymentPendingError {
            // Awaiting approval (e.g. Ask to Buy) — not a failure.
        } catch {
            errorMessage = L("premium.error")
        }
        isPurchasing = false
    }

    /// App Store review requirement: recovers the subscription on a new
    /// device with the same Apple ID.
    func restore() async {
        guard !isPurchasing else { return }
        isPurchasing = true
        do {
            let info = try await Purchases.shared.restorePurchases()
            apply(info)
            restoreMessage = isPremium ? L("premium.restore.done") : L("premium.restore.none")
        } catch {
            errorMessage = L("premium.error")
        }
        isPurchasing = false
    }

    private func apply(_ info: CustomerInfo) {
        let entitlement = info.entitlements["premium"]
        let active = entitlement?.isActive == true
        let wasActive = isPremium
        isPremium = active
        UserDefaults.standard.set(active, forKey: Self.cacheKey)

        if active, entitlement?.periodType == .trial {
            // Trial running: full Premium (ads off everywhere, features on)
            // and an honest reminder the day before it ends.
            UserDefaults.standard.set(true, forKey: Self.trialActiveKey)
            scheduleTrialEndReminder(expirationDate: entitlement?.expirationDate)
        } else {
            if active {
                // Renewed at the regular price after a trial: conversion.
                if UserDefaults.standard.bool(forKey: Self.trialActiveKey) {
                    UserDefaults.standard.set(false, forKey: Self.trialActiveKey)
                    AnalyticsService.shared.log("trial_converted")
                }
                cancelTrialEndReminder()
            } else if wasActive || UserDefaults.standard.bool(forKey: Self.trialActiveKey) {
                // Trial cancelled or subscription expired: back to free.
                // Watchlist, diary and every other datum are untouched.
                if UserDefaults.standard.bool(forKey: Self.trialActiveKey) {
                    UserDefaults.standard.set(false, forKey: Self.trialActiveKey)
                    AnalyticsService.shared.log("trial_cancelled")
                }
                cancelTrialEndReminder()
            }
        }
    }

    /// Local notification on the second-to-last day of the trial: honest
    /// wording, no pressure. Only fires if notifications are authorized.
    private func scheduleTrialEndReminder(expirationDate: Date?) {
        guard let expiration = expirationDate else { return }
        guard let fireDay = Calendar.current.date(byAdding: .day, value: -1, to: expiration) else { return }

        var components = Calendar.current.dateComponents([.year, .month, .day], from: fireDay)
        components.hour = 10

        let content = UNMutableNotificationContent()
        content.title = L("trial.reminder.title")
        content.body = L("trial.reminder.body")
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: Self.trialReminderId,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.trialReminderId])
        Task { try? await center.add(request) }
    }

    private func cancelTrialEndReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.trialReminderId])
    }
}
