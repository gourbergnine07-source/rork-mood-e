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

    private var update: AppUpdateService { .shared }

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
                        // Gli abbonati Premium non vedono pubblicità: verifica lo
                        // stato prima di avviare l'SDK annunci. Per gli altri:
                        // ATT prompt (solo al primo avvio), poi avvio del SDK.
                        await PremiumStore.shared.refreshStatus()
                        guard !PremiumStore.shared.isPremium else { return }
                        await AdsManager.shared.requestTrackingAndStart()
                    }
            }

            // Mandatory update (remote `minimum_required_version`): covers
            // every phase, including the splash, and can't be dismissed.
            if update.isBlocking {
                ForcedUpdateView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: update.isBlocking)
    }
}

#Preview {
    RootView()
        .environment(MovieLibrary())
        .environment(NotificationService())
        .environment(MoodDiary())
}
