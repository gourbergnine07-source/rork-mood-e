//
//  NativeAdCardView.swift
//  MoodE
//

import SwiftUI
import GoogleMobileAds

/// Native ad slot for the results list. The ad is claimed from the
/// preload pool in `.task` (never during view rendering), so a slot with
/// no ready ad simply renders nothing. Styled like `MovieCard` but with a
/// clearly visible localized "Annuncio" label; impressions, clicks and
/// AdChoices are managed by the AdMob SDK.
struct NativeAdCardView: View {
    @State private var ad: NativeAd?

    var body: some View {
        Group {
            if let ad {
                nativeCard(ad)
            }
        }
        .task {
            ad = NativeAdManager.shared.take()
        }
    }

    private func nativeCard(_ ad: NativeAd) -> some View {
        NativeAdRepresentable(nativeAd: ad)
            .background(Theme.card, in: .rect(cornerRadius: 22))
            .overlay(alignment: .topTrailing) {
                Text(L("ads.native.label"))
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.amber.opacity(0.85), in: .capsule)
                    .padding(8)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Theme.primary.opacity(0.10), lineWidth: 1)
                    .allowsHitTesting(false)
            )
    }
}

private struct NativeAdRepresentable: UIViewRepresentable {
    let nativeAd: NativeAd

    func makeUIView(context: Context) -> NativeAdView {
        let adView = NativeAdView()
        adView.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [])
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(stack)

        let iconView = UIImageView()
        iconView.contentMode = .scaleAspectFill
        iconView.layer.cornerRadius = 12
        iconView.layer.masksToBounds = true
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 56).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 56).isActive = true

        let textStack = UIStackView(arrangedSubviews: [])
        textStack.axis = .vertical
        textStack.spacing = 4

        let headline = UILabel()
        headline.font = .preferredFont(forTextStyle: .headline)
        headline.textColor = UIColor(Theme.ink)
        headline.numberOfLines = 2

        let body = UILabel()
        body.font = .preferredFont(forTextStyle: .footnote)
        body.textColor = UIColor(Theme.inkSoft)
        body.numberOfLines = 2

        textStack.addArrangedSubview(headline)
        textStack.addArrangedSubview(body)

        let cta = UIButton(type: .system)
        cta.titleLabel?.font = .systemFont(ofSize: 15, weight: .bold)
        cta.setTitleColor(.white, for: .normal)
        cta.backgroundColor = UIColor(Theme.primary)
        cta.layer.cornerRadius = 16
        cta.contentEdgeInsets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
        cta.isUserInteractionEnabled = false // the SDK owns the taps
        cta.translatesAutoresizingMaskIntoConstraints = false
        cta.heightAnchor.constraint(equalToConstant: 32).isActive = true

        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(textStack)
        stack.addArrangedSubview(cta)
        textStack.setContentHuggingPriority(.defaultLow, for: .horizontal)
        cta.setContentCompressionResistancePriority(.required, for: .horizontal)
        cta.setContentHuggingPriority(.required, for: .horizontal)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: adView.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -14)
        ])

        adView.headlineView = headline
        adView.bodyView = body
        adView.iconView = iconView
        adView.callToActionView = cta

        // Assets first, then the ad object: this is what activates
        // SDK-managed clicks, impressions and the AdChoices overlay.
        headline.text = nativeAd.headline
        body.text = nativeAd.body
        cta.setTitle(nativeAd.callToAction, for: .normal)
        iconView.image = nativeAd.icon?.image
        adView.nativeAd = nativeAd

        return adView
    }

    func updateUIView(_ uiView: NativeAdView, context: Context) {}
}
