//
//  PremiumStore.swift
//  MoodE
//

import Foundation
import Observation
import RevenueCat

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
    var isPurchasing: Bool = false
    var errorMessage: String?
    /// One-shot feedback after "Ripristina acquisti".
    var restoreMessage: String?

    private init() {
        isPremium = UserDefaults.standard.bool(forKey: Self.cacheKey)
    }

    /// Synchronous check for early-launch paths (ads, App Intents).
    static var isPremiumCached: Bool {
        UserDefaults.standard.bool(forKey: cacheKey)
    }

    /// Must be called once from the App's `init()`, before any other use.
    static func configureSDK() {
        #if DEBUG
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: Config.EXPO_PUBLIC_REVENUECAT_TEST_API_KEY)
        #else
        Purchases.configure(withAPIKey: Config.EXPO_PUBLIC_REVENUECAT_IOS_API_KEY)
        #endif
    }

    /// Begins listening for entitlement changes and loads the offering.
    func start() {
        Task { await listenForUpdates() }
        Task { await fetchOfferings() }
    }

    /// The monthly plan shown on the paywall.
    var monthlyPackage: Package? {
        offerings?.current?.monthly ?? offerings?.current?.availablePackages.first
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
        guard offerings == nil, !isLoading else { return }
        isLoading = true
        do {
            offerings = try await Purchases.shared.offerings()
        } catch {
            print("PremiumStore: offerings failed: \(error.localizedDescription)")
        }
        isLoading = false
    }

    func purchase() async {
        guard let package = monthlyPackage, !isPurchasing else { return }
        isPurchasing = true
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if !result.userCancelled {
                apply(result.customerInfo)
                AnalyticsService.shared.log("premium_purchased")
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
        let active = info.entitlements["premium"]?.isActive == true
        isPremium = active
        UserDefaults.standard.set(active, forKey: Self.cacheKey)
    }
}
