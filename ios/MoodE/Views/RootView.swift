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
            }
        }
    }
}

#Preview {
    RootView()
        .environment(MovieLibrary())
        .environment(NotificationService())
}
