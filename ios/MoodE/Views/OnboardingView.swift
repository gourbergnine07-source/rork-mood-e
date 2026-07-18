//
//  OnboardingView.swift
//  MoodE
//

import SwiftUI

/// Single onboarding slide model.
struct OnboardingSlide: Identifiable {
    let id: Int
    let icon: String
    let title: String
    let message: String
}

/// First-launch onboarding: three slides explaining the
/// emozione → obiettivo → epoca → proposta flow.
struct OnboardingView: View {
    let onFinished: () -> Void

    @State private var currentPage = 0

    private let slides: [OnboardingSlide] = [
        OnboardingSlide(
            id: 0,
            icon: "face.smiling.inverse",
            title: "Dicci come ti senti",
            message: "Apri Mood-E e scegli la tua emozione del momento: felice, malinconico, stressato… ce n'è per tutti gli stati d'animo."
        ),
        OnboardingSlide(
            id: 1,
            icon: "scope",
            title: "Obiettivo ed epoca",
            message: "Scegli cosa vuoi provare guardando il film — ridere, commuoverti, rilassarti — e l'epoca che preferisci, dai classici alle novità."
        ),
        OnboardingSlide(
            id: 2,
            icon: "sparkles.tv.fill",
            title: "La proposta su misura",
            message: "Ricevi subito film scelti per te: guarda il trailer, salvali nella tua lista e scopri cosa c'è al cinema vicino a te."
        )
    ]

    private var isLastPage: Bool {
        currentPage == slides.count - 1
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if !isLastPage {
                        Button("Salta") {
                            onFinished()
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.inkSoft)
                        .padding(.trailing, 24)
                        .padding(.top, 8)
                    }
                }
                .frame(height: 44)

                TabView(selection: $currentPage) {
                    ForEach(slides) { slide in
                        OnboardingSlideView(slide: slide, stepIndex: slide.id)
                            .tag(slide.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: currentPage)

                VStack(spacing: 24) {
                    HStack(spacing: 8) {
                        ForEach(slides) { slide in
                            Capsule()
                                .fill(slide.id == currentPage ? Theme.primary : Theme.primary.opacity(0.25))
                                .frame(width: slide.id == currentPage ? 26 : 8, height: 8)
                        }
                    }
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: currentPage)

                    Button {
                        if isLastPage {
                            onFinished()
                        } else {
                            withAnimation {
                                currentPage += 1
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(isLastPage ? "Inizia" : "Avanti")
                                .font(.headline)
                            Image(systemName: isLastPage ? "sparkles" : "arrow.right")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Theme.primary, in: .rect(cornerRadius: 18))
                        .shadow(color: Theme.primary.opacity(0.35), radius: 10, y: 5)
                    }
                    .buttonStyle(PressableCardStyle())
                    .sensoryFeedback(.impact(weight: .light), trigger: currentPage)
                    .padding(.horizontal, 28)
                }
                .padding(.bottom, 36)
            }
        }
    }
}

/// One onboarding page: big icon in layered circles, step badge, title and message.
struct OnboardingSlideView: View {
    let slide: OnboardingSlide
    let stepIndex: Int

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.primary.opacity(0.10))
                    .frame(width: 190, height: 190)
                Circle()
                    .fill(Theme.primary.opacity(0.14))
                    .frame(width: 148, height: 148)
                Image(systemName: slide.icon)
                    .font(.system(size: 62))
                    .foregroundStyle(Theme.primary)
            }

            VStack(spacing: 14) {
                Text("Passo \(stepIndex + 1) di 3")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Theme.primary.opacity(0.12), in: .capsule)

                Text(slide.title)
                    .font(.title.weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)

                Text(slide.message)
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 8)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

#Preview {
    OnboardingView(onFinished: {})
}
