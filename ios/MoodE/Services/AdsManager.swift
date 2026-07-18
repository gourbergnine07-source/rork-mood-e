//
//  AdsManager.swift
//  MoodE
//

import Foundation
import UIKit
import Observation
import GoogleMobileAds
import AppTrackingTransparency

/// Central AdMob coordinator: ATT consent, SDK startup, interstitial
/// rate limiting and rewarded ads. When tracking is denied, every request
/// is flagged as non-personalized ("npa") so the app keeps monetizing
/// without personal data.
@Observable
final class AdsManager: NSObject, FullScreenContentDelegate {
    static let shared = AdsManager()

    /// Ad Unit ID di TEST Google: sostituire con quelli reali del proprio
    /// account AdMob SOLO prima della pubblicazione su App Store.
    enum AdUnit {
        static let banner = "ca-app-pub-3940256099942544/2435281174"
        static let interstitial = "ca-app-pub-3940256099942544/4411468910"
        static let rewarded = "ca-app-pub-3940256099942544/1712485313"
    }

    private(set) var isStarted = false
    private(set) var isRewardedReady = false

    private var interstitial: InterstitialAd?
    private var rewarded: RewardedAd?
    private var pendingInterstitialCompletion: (() -> Void)?
    private var onRewardEarned: (() -> Void)?
    private var rewardWasEarned = false
    private var isShowingRewarded = false

    // MARK: - Rate limiting (persisted)

    private let defaults = UserDefaults.standard
    private let searchCountKey = "ads.searchCount"
    private let lastInterstitialKey = "ads.lastInterstitialDate"
    /// Max 1 interstitial "di ritorno" ogni 5 minuti.
    private let interstitialCooldown: TimeInterval = 5 * 60
    /// Interstitial dopo il flusso: al massimo 1 ogni 3 ricerche.
    private let searchesPerInterstitial = 3

    private override init() {
        super.init()
    }

    private var isTrackingAuthorized: Bool {
        ATTrackingManager.trackingAuthorizationStatus == .authorized
    }

    // MARK: - Startup & ATT

    /// Shows the system ATT prompt (first time only), then starts the SDK
    /// and preloads full-screen ads. Called after onboarding, before any ad.
    func requestTrackingAndStart() async {
        guard !isStarted else { return }
        _ = await ATTrackingManager.requestTrackingAuthorization()
        _ = await MobileAds.shared.start()
        isStarted = true
        preloadInterstitial()
        preloadRewarded()
    }

    /// Builds an ad request; adds the "npa" flag when tracking was denied
    /// so only non-personalized ads are served.
    func makeRequest() -> Request {
        let request = Request()
        if !isTrackingAuthorized {
            let extras = Extras()
            extras.additionalParameters = ["npa": "1"]
            request.register(extras)
        }
        return request
    }

    // MARK: - Interstitial

    private func preloadInterstitial() {
        guard interstitial == nil else { return }
        Task {
            do {
                let ad = try await InterstitialAd.load(with: AdUnit.interstitial, request: makeRequest())
                ad.fullScreenContentDelegate = self
                interstitial = ad
            } catch {
                print("AdsManager: interstitial non caricato: \(error.localizedDescription)")
            }
        }
    }

    /// Called when the mood flow completes. Shows an interstitial at most
    /// once every `searchesPerInterstitial` searches, then runs `completion`
    /// (immediately when no ad is due) so the user's action is never lost.
    func showSearchInterstitialIfDue(then completion: @escaping () -> Void) {
        let count = defaults.integer(forKey: searchCountKey) + 1
        defaults.set(count, forKey: searchCountKey)

        guard isStarted,
              count % searchesPerInterstitial == 0,
              let ad = interstitial else {
            completion()
            return
        }
        presentInterstitial(ad, completion: completion)
    }

    /// Called when the user returns from a movie detail screen.
    /// Rate limited to 1 interstitial every 5 minutes of use.
    func maybeShowReturnInterstitial() {
        guard isStarted, interstitial != nil else { return }
        let last = defaults.double(forKey: lastInterstitialKey)
        guard Date().timeIntervalSince1970 - last >= interstitialCooldown else { return }

        Task {
            // Let the pop transition settle before covering the screen.
            try? await Task.sleep(for: .milliseconds(550))
            guard let ad = interstitial else { return }
            presentInterstitial(ad, completion: nil)
        }
    }

    private func presentInterstitial(_ ad: InterstitialAd, completion: (() -> Void)?) {
        pendingInterstitialCompletion = completion
        defaults.set(Date().timeIntervalSince1970, forKey: lastInterstitialKey)
        interstitial = nil
        ad.present(from: nil)
    }

    // MARK: - Rewarded

    private func preloadRewarded() {
        guard rewarded == nil else { return }
        Task {
            do {
                let ad = try await RewardedAd.load(with: AdUnit.rewarded, request: makeRequest())
                ad.fullScreenContentDelegate = self
                rewarded = ad
                isRewardedReady = true
            } catch {
                print("AdsManager: rewarded non caricato: \(error.localizedDescription)")
                isRewardedReady = false
            }
        }
    }

    /// Presents the rewarded ad; `onReward` runs only after the user
    /// actually earned the reward, once the ad is dismissed.
    func showRewarded(onReward: @escaping () -> Void) {
        guard let ad = rewarded else { return }
        rewarded = nil
        isRewardedReady = false
        isShowingRewarded = true
        rewardWasEarned = false
        onRewardEarned = onReward

        ad.present(from: nil) { [weak self] in
            Task { @MainActor in
                self?.rewardWasEarned = true
            }
        }
    }

    // MARK: - FullScreenContentDelegate

    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            self.handleFullScreenDismiss()
        }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            self.handleFullScreenDismiss()
        }
    }

    private func handleFullScreenDismiss() {
        let completion = pendingInterstitialCompletion
        pendingInterstitialCompletion = nil

        if isShowingRewarded {
            isShowingRewarded = false
            if rewardWasEarned {
                rewardWasEarned = false
                onRewardEarned?()
            }
            onRewardEarned = nil
            preloadRewarded()
        } else {
            preloadInterstitial()
        }
        completion?()
    }
}
