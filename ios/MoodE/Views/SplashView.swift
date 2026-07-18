//
//  SplashView.swift
//  MoodE
//

import SwiftUI

/// Opening splash: logo, app name and tagline with a gentle
/// staggered entrance, then hands off to the main content.
struct SplashView: View {
    let onFinished: () -> Void

    @State private var showLogo = false
    @State private var showText = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 22) {
                Image("film_strip_heart_gold")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 132, height: 132)
                    .clipShape(.rect(cornerRadius: 30))
                    .shadow(color: Theme.primary.opacity(0.25), radius: 18, y: 10)
                    .scaleEffect(showLogo ? 1 : 0.7)
                    .opacity(showLogo ? 1 : 0)

                VStack(spacing: 8) {
                    Text("Mood-E")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ink)

                    Text(L("app.tagline"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.inkSoft)
                }
                .opacity(showText ? 1 : 0)
                .offset(y: showText ? 0 : 12)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Mood-E. \(L("app.tagline"))")
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                showLogo = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.35)) {
                showText = true
            }
            Task {
                try? await Task.sleep(for: .seconds(1.8))
                onFinished()
            }
        }
    }
}

#Preview {
    SplashView(onFinished: {})
}
