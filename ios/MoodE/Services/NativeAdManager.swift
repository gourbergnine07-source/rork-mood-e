//
//  NativeAdManager.swift
//  MoodE
//

import Foundation
import Observation
import GoogleMobileAds
import UIKit

/// Preloads native ads for the results list. Loading goes through
/// `AdLoader` (the only supported entry point for native ads); the pool
/// is intentionally small (max 2 on screen) and every consumed ad is
/// replaced in the background so a request almost always becomes a real
/// impression.
@Observable
final class NativeAdManager: NSObject, NativeAdLoaderDelegate, NativeAdDelegate {
    static let shared = NativeAdManager()

    /// Pool size: at most 2 native cards are ever mounted per results screen.
    private let poolSize = 2

    /// Ads ready to be shown (oldest first).
    private(set) var ads: [NativeAd] = []

    private var loader: AdLoader?
    private var attempts = 0

    /// Max 3 preload attempts with growing waits, same policy as the
    /// other formats.
    private let retryDelays: [Duration] = [.seconds(10), .seconds(30), .seconds(90)]

    private override init() {
        super.init()
    }

    /// Fills the pool. Called after the SDK starts and after each ad is
    /// consumed; safe to call repeatedly.
    func preload() {
        guard attempts < retryDelays.count, ads.count < poolSize else { return }
        let attempt = attempts + 1
        attempts = attempt
        AnalyticsService.shared.log("ad_request", meta: ["format": "native"])

        let loader = AdLoader(
            adUnitID: AdsManager.AdUnit.native,
            rootViewController: Self.topViewController(),
            adTypes: [.native],
            options: nil
        )
        loader.delegate = self
        self.loader = loader
        loader.load(AdsManager.shared.makeRequest())
    }

    /// Removes the oldest ready ad so it can be mounted exactly once; the
    /// pool refills in the background.
    @discardableResult
    func take() -> NativeAd? {
        guard !ads.isEmpty else { return nil }
        let ad = ads.removeFirst()
        preload()
        return ad
    }

    // MARK: - NativeAdLoaderDelegate

    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        attempts = 0
        nativeAd.delegate = self
        Task { @MainActor in
            self.ads.append(nativeAd)
        }
    }

    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        print("NativeAdManager: non caricato (tentativo \(attempts)): \(error.localizedDescription)")
        Task { @MainActor in
            try? await Task.sleep(for: self.retryDelays[max(0, self.attempts - 1)])
            self.preload()
        }
    }

    // MARK: - NativeAdDelegate (eventi anonimi per i report AdMob)

    func nativeAdDidRecordImpression(_ nativeAd: NativeAd) {
        AnalyticsService.shared.log("ad_impression", meta: ["format": "native"])
    }

    func nativeAdDidRecordClick(_ nativeAd: NativeAd) {
        AnalyticsService.shared.log("ad_click", meta: ["format": "native"])
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
        let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        guard let root = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return nil
        }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}
