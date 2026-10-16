//
//  AdsManager.swift
//  MoodE
//

import Foundation
import UIKit
import Observation
import GoogleMobileAds
import UserMessagingPlatform
import AppTrackingTransparency

/// Central AdMob coordinator: GDPR consent (UMP), ATT, SDK startup,
/// preloading with backoff retry, rate limiting, and rewarded ads.
/// When tracking is denied, every request is flagged as non-personalized
/// ("npa") so the app keeps monetizing without personal data.
@Observable
final class AdsManager: NSObject, FullScreenContentDelegate {
    static let shared = AdsManager()

    /// Ad Unit ID dell'account AdMob di Mood-E. I formati con unità non
    /// ancora create in AdMob usano gli ID di test Google: sostituire
    /// l'ID reale appena disponibile, senza toccare altro codice.
    enum AdUnit {
        static let banner = "ca-app-pub-7245682186872516/8638257086"
        static let interstitial = "ca-app-pub-7245682186872516/4287828396"
        static let rewarded = "ca-app-pub-7245682186872516/6750460342"
        /// Unità "Native advanced" creata in AdMob (MoodE_Native_iOS).
        static let native = "ca-app-pub-7245682186872516/4952423203"
    }

    private(set) var isStarted = false
    private(set) var isRewardedReady = false
    private(set) var isConsentReady = false
    /// Rewarded guarditi oggi (osservabile: i bottoni reagiscono al cap).
    private(set) var rewardedToday = 0

    /// In the simulator AdMob only ever fills banner slots with test
    /// placeholders, badged with a "Test mode" label. Those badges were
    /// ending up baked into App Store screenshots, so banners are not
    /// mounted there. Device builds — including every App Store build —
    /// are unaffected and keep serving real banners.
    static var isBannerRenderingSuppressed: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    private var interstitial: InterstitialAd?
    private var rewarded: RewardedAd?
    private var pendingInterstitialCompletion: (() -> Void)?
    private var onRewardEarned: (() -> Void)?
    private var rewardWasEarned = false
    private var isShowingRewarded = false

    // MARK: - Rate limiting (persisted)

    private let defaults = UserDefaults.standard
    private let dayKey = "ads.day"
    private let searchCountKey = "ads.searchCount"
    private let interstitialTodayKey = "ads.interstitialToday"
    private let rewardedTodayKey = "ads.rewardedToday"
    private let lastInterstitialKey = "ads.lastInterstitialDate"
    private let lastRewardKey = "ads.lastRewardDate"
    private let lastTrailerKey = "ads.lastTrailerDate"

    /// Max 1 interstitial ogni 4 minuti di uso attivo.
    private let interstitialCooldown: TimeInterval = 4 * 60
    /// Mai un interstitial così vicina alla chiusura di un rewarded/trailer.
    private let postFullScreenQuietPeriod: TimeInterval = 3 * 60
    /// Massimi giornalieri per non stressare l'esperienza.
    private let maxInterstitialsPerDay = 4
    private let maxRewardedPerDay = 3
    /// Interstitial dopo il flusso: al massimo 1 ogni 3 ricerche.
    private let searchesPerInterstitial = 3

    // MARK: - Preload retry (attesa crescente, massimo 3 tentativi)

    private static let retryDelays: [Duration] = [.seconds(10), .seconds(30), .seconds(90)]
    private var interstitialAttempts = 0
    private var rewardedAttempts = 0

    private override init() {
        super.init()
        rollDayIfNeeded()
        rewardedToday = defaults.integer(forKey: rewardedTodayKey)
    }

    private var isTrackingAuthorized: Bool {
        ATTrackingManager.trackingAuthorizationStatus == .authorized
    }

    // MARK: - Consenso (UMP GDPR) & avvio

    /// GDPR: legge/aggiorna il consenso con l'UMP SDK e, nei paesi dove è
    /// richiesto, mostra il form Google prima di qualsiasi richiesta di
    /// annunci. Fuori dall'EEA/UK la chiamata è un no-op veloce.
    private func gatherConsent() async {
        if isConsentReady { return }
        let parameters = RequestParameters()

        #if DEBUG && targetEnvironment(simulator)
        // Test GDPR: nel simulatore forza la giurisdizione EEA così il
        // form di consenso Google compare sempre. L'UMP SDK tratta il
        // simulatore come test device, quindi nessun ID debug necessario.
        // Mai attivo nelle build Release/device (DEBUG non è definito).
        let debugSettings = DebugSettings()
        debugSettings.geography = DebugGeography.EEA
        parameters.debugSettings = debugSettings
        print("AdsManager: UMP debug geography forzata su EEA (simulatore)")
        #endif

        var requestError: Error?
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { error in
                requestError = error
                continuation.resume()
            }
        }

        if let requestError {
            print("AdsManager: UMP requestConsentInfoUpdate errore: \(requestError.localizedDescription)")
        } else {
            print("AdsManager: UMP consent status=\(ConsentInformation.shared.consentStatus.rawValue) (0=unknown 1=required 2=obtained 3=notRequired)")
        }

        // Nei paesi con GDPR mostra il form Google se serve; altrove no-op.
        do {
            try await ConsentForm.loadAndPresentIfRequired(from: Self.topViewController())
        } catch {
            print("AdsManager: UMP form errore: \(error.localizedDescription)")
        }
        print("AdsManager: UMP status post-form=\(ConsentInformation.shared.consentStatus.rawValue) (2=obtained), canRequestAds=\(ConsentInformation.shared.canRequestAds)")

        isConsentReady = true
    }

    /// Shows the UMP consent form when required, the system ATT prompt
    /// (first time only), then starts the SDK and preloads every format.
    /// Called after onboarding, before any ad.
    ///
    /// The ATT prompt is skipped while iOS would render it in a language
    /// other than the app UI (the launch where the user picks a language
    /// different from the device one). App Store guideline 4 requires
    /// permission requests to match the app's localization, so it is asked
    /// from the next launch on; meanwhile ads are served as
    /// non-personalized.
    func requestTrackingAndStart() async {
        // Premium: nessuna pubblicità, l'SDK non viene nemmeno avviato.
        guard !PremiumStore.shared.isPremium else { return }
        guard !isStarted else { return }

        await gatherConsent()

        // Rifiuto del consenso (o form mai completato): nessun annuncio.
        guard ConsentInformation.shared.canRequestAds else { return }

        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined,
           LocalizationManager.shared.canShowSystemPrompts {
            _ = await ATTrackingManager.requestTrackingAuthorization()
        }

        _ = await MobileAds.shared.start()
        isStarted = true
        preloadInterstitial()
        preloadRewarded()
        NativeAdManager.shared.preload()
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
        guard interstitial == nil, interstitialAttempts < Self.retryDelays.count else { return }
        let attempt = interstitialAttempts + 1
        interstitialAttempts = attempt
        AnalyticsService.shared.log("ad_request", meta: ["format": "interstitial"])

        Task {
            do {
                let ad = try await InterstitialAd.load(with: AdUnit.interstitial, request: makeRequest())
                ad.fullScreenContentDelegate = self
                interstitial = ad
                interstitialAttempts = 0
            } catch {
                // Retry con attesa crescente; a fine tentativi il bottone
                // interessato semplicemente non compare.
                print("AdsManager: interstitial non caricato (tentativo \(attempt)): \(error.localizedDescription)")
                try? await Task.sleep(for: Self.retryDelays[attempt - 1])
                await MainActor.run { self.preloadInterstitial() }
            }
        }
    }

    /// Called when the mood flow completes. Shows an interstitial at most
    /// once every `searchesPerInterstitial` searches (max 4/day, min 4
    /// minutes apart, never right after a rewarded ad), then runs
    /// `completion` (immediately when no ad is due) so the user's action
    /// is never lost.
    func showSearchInterstitialIfDue(then completion: @escaping () -> Void) {
        guard !PremiumStore.shared.isPremium else {
            completion()
            return
        }
        rollDayIfNeeded()
        let count = defaults.integer(forKey: searchCountKey) + 1
        defaults.set(count, forKey: searchCountKey)

        guard isStarted,
              count % searchesPerInterstitial == 0,
              canShowFullScreenAd,
              defaults.integer(forKey: interstitialTodayKey) < maxInterstitialsPerDay,
              let ad = interstitial else {
            completion()
            return
        }
        presentInterstitial(ad, completion: completion)
    }

    /// Called when the user returns from a movie detail screen.
    /// Rate limited to 1 interstitial every 4 minutes of use, max 4/day,
    /// never while a trailer was just watched.
    func maybeShowReturnInterstitial() {
        guard !PremiumStore.shared.isPremium else { return }
        guard isStarted, canShowFullScreenAd,
              defaults.integer(forKey: interstitialTodayKey) < maxInterstitialsPerDay,
              interstitial != nil else { return }
        let last = defaults.double(forKey: lastInterstitialKey)
        guard Date().timeIntervalSince1970 - last >= interstitialCooldown else { return }

        Task {
            // Let the pop transition settle before covering the screen.
            try? await Task.sleep(for: .milliseconds(550))
            guard let ad = interstitial, canShowFullScreenAd else { return }
            presentInterstitial(ad, completion: nil)
        }
    }

    /// True when no full-screen ad of the same family was dismissed (or a
    /// trailer closed) too recently: never interrupt right after a reward.
    private var canShowFullScreenAd: Bool {
        let now = Date().timeIntervalSince1970
        let afterReward = now - defaults.double(forKey: lastRewardKey) < postFullScreenQuietPeriod
        let afterTrailer = now - defaults.double(forKey: lastTrailerKey) < 60
        return !(afterReward || afterTrailer)
    }

    /// Recorded when the trailer player sheet closes: no interstitial may
    /// interrupt for a short while after watching one.
    func noteTrailerEnded() {
        defaults.set(Date().timeIntervalSince1970, forKey: lastTrailerKey)
    }

    private func presentInterstitial(_ ad: InterstitialAd, completion: (() -> Void)?) {
        pendingInterstitialCompletion = completion
        defaults.set(Date().timeIntervalSince1970, forKey: lastInterstitialKey)
        interstitial = nil
        bump(interstitialTodayKey)
        ad.present(from: nil)
    }

    // MARK: - Rewarded

    private func preloadRewarded() {
        guard rewarded == nil, rewardedAttempts < Self.retryDelays.count else { return }
        let attempt = rewardedAttempts + 1
        rewardedAttempts = attempt
        AnalyticsService.shared.log("ad_request", meta: ["format": "rewarded"])

        Task {
            do {
                let ad = try await RewardedAd.load(with: AdUnit.rewarded, request: makeRequest())
                ad.fullScreenContentDelegate = self
                rewarded = ad
                isRewardedReady = true
                rewardedAttempts = 0
            } catch {
                print("AdsManager: rewarded non caricato (tentativo \(attempt)): \(error.localizedDescription)")
                isRewardedReady = false
                try? await Task.sleep(for: Self.retryDelays[attempt - 1])
                await MainActor.run { self.preloadRewarded() }
            }
        }
    }

    /// True when the user can still watch a rewarded ad today (max 3/day).
    var canShowRewarded: Bool {
        isStarted && isRewardedReady && rewardedToday < maxRewardedPerDay
    }

    /// Rewarded extras still unlockable today (for the results counter).
    var rewardedRemainingToday: Int { max(0, maxRewardedPerDay - rewardedToday) }
    /// Daily rewarded cap, exposed so UI can format "x di y".
    var rewardedMaxPerDay: Int { maxRewardedPerDay }

    /// Presents the rewarded ad; `onReward` runs only after the user
    /// actually earned the reward, once the ad is dismissed.
    func showRewarded(onReward: @escaping () -> Void) {
        guard canShowRewarded, let ad = rewarded else { return }
        rewarded = nil
        isRewardedReady = false
        isShowingRewarded = true
        rewardWasEarned = false
        onRewardEarned = onReward
        bump(rewardedTodayKey)

        ad.present(from: nil) { [weak self] in
            Task { @MainActor in
                self?.rewardWasEarned = true
            }
        }
    }

    // MARK: - FullScreenContentDelegate

    nonisolated func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            AnalyticsService.shared.log("ad_impression", meta: [
                "format": self.isShowingRewarded ? "rewarded" : "interstitial"
            ])
        }
    }

    nonisolated func adDidRecordClick(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            AnalyticsService.shared.log("ad_click", meta: [
                "format": self.isShowingRewarded ? "rewarded" : "interstitial"
            ])
        }
    }

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
                defaults.set(Date().timeIntervalSince1970, forKey: lastRewardKey)
                AnalyticsService.shared.log("ad_reward", meta: ["format": "rewarded"])
                onRewardEarned?()
            }
            onRewardEarned = nil
            preloadRewarded()
        } else {
            preloadInterstitial()
        }
        completion?()
    }

    // MARK: - Giorni e contatori

    private func bump(_ key: String) {
        defaults.set(defaults.integer(forKey: key) + 1, forKey: key)
        if key == rewardedTodayKey {
            rewardedToday = defaults.integer(forKey: key)
        }
    }

    private func rollDayIfNeeded() {
        let today = Self.today()
        guard defaults.string(forKey: dayKey) != today else { return }
        defaults.set(today, forKey: dayKey)
        defaults.set(0, forKey: interstitialTodayKey)
        defaults.set(0, forKey: rewardedTodayKey)
        rewardedToday = 0
    }

    private static func today() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    /// Top-most view controller for presenting the UMP consent form.
    private static func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first,
            let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return nil
        }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}

/// Wrapper per `UserDefaults`, re-esposto qui per l'accesso ai contatori
/// giornalieri dal resto del modulo pubblicità.
extension AdsManager {
    var dailyCounters: UserDefaults { defaults }
}
