//
//  RootView.swift
//  MoodE
//

import SwiftUI

/// Launch flow coordinator: splash → onboarding (first launch only) → main tabs.
/// All phase changes cross-fade so the entrance feels seamless.
struct RootView: View {
    private enum LaunchPhase {
        case splash
        case language
        case onboarding
        case ready
    }

    @State private var phase: LaunchPhase = .splash
    @AppStorage("onboarding.completed") private var hasCompletedOnboarding: Bool = false

    var body: some View {
        ZStack {
            switch phase {
            case .splash:
                SplashView {
                    withAnimation(.easeInOut(duration: 0.45)) {
                        if !LocalizationManager.shared.hasChosenLanguage {
                            phase = .language
                        } else {
                            phase = hasCompletedOnboarding ? .ready : .onboarding
                        }
                    }
                }
                .transition(.opacity)

            case .language:
                LanguageSelectionView {
                    withAnimation(.easeInOut(duration: 0.45)) {
                        phase = hasCompletedOnboarding ? .ready : .onboarding
                    }
                }
                .transition(.opacity)

            case .onboarding:
                OnboardingView {
                    hasCompletedOnboarding = true
                    withAnimation(.easeInOut(duration: 0.45)) {
                        phase = .ready
                    }
                }
                .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .leading).combined(with: .opacity)))

            case .ready:
                ContentView()
                    .transition(.opacity)
                    .task {
                        // ATT prompt (solo al primo avvio, dopo l'onboarding),
                        // poi avvio del SDK annunci: nessun annuncio prima del consenso.
                        await AdsManager.shared.requestTrackingAndStart()
                    }
            }
        }
    }
}

#Preview {
    RootView()
        .environment(MovieLibrary())
        .environment(NotificationService())
}
