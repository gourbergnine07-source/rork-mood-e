//
//  AdBannerView.swift
//  MoodE
//

import SwiftUI
import UIKit
import GoogleMobileAds

/// Anchored adaptive AdMob banner. Meant to be mounted with
/// `.safeAreaInset(edge: .bottom)` so it reserves its own space and can
/// never overlap interactive content above it. Renders nothing until the
/// SDK has started (i.e. after the ATT prompt).
struct AdBannerView: View {
    private var ads: AdsManager { AdsManager.shared }

    var body: some View {
        // Premium: nessun banner in tutta l'app.
        if ads.isStarted, !PremiumStore.shared.isPremium {
            let width = UIScreen.main.bounds.width
            let adSize = currentOrientationAnchoredAdaptiveBanner(width: width)
            BannerViewRepresentable(adSize: adSize)
                .frame(height: adSize.size.height)
                .frame(maxWidth: .infinity)
                .background(Theme.background)
        }
    }
}

private struct BannerViewRepresentable: UIViewRepresentable {
    let adSize: AdSize

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: adSize)
        banner.adUnitID = AdsManager.AdUnit.banner
        banner.load(AdsManager.shared.makeRequest())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}
}
