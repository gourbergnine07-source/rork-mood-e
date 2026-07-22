//
//  FeaturedStripView.swift
//  MoodE
//

import SwiftUI

/// "In evidenza" carousel at the top of Home: horizontally scrollable compact
/// cards (~75% of screen width, so the next card peeks in) for every active
/// editorial collection, plus the spectator-quiz invitation as the last card.
struct FeaturedStripView: View {
    @Environment(QuizStore.self) private var quiz
    @Binding var showQuiz: Bool
    @Binding var showPaywall: Bool
    @Binding var quizBannerHidden: Bool

    private let collections: [FeaturedCollection] = FeaturedCalendar.activeCollections()

    private var isPremium: Bool { PremiumStore.shared.isPremium }

    var body: some View {
        if !collections.isEmpty || !quizBannerHidden {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.amber)
                    Text(L("home.featured.title"))
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Theme.ink)
                }
                .padding(.horizontal, 24)

                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(collections) { collection in
                            NavigationLink(value: collection) {
                                FeaturedCardView(collection: collection)
                            }
                            .buttonStyle(PressableCardStyle())
                            .containerRelativeFrame(.horizontal) { length, _ in
                                length * 0.75
                            }
                        }

                        if !quizBannerHidden {
                            quizCard
                                .containerRelativeFrame(.horizontal) { length, _ in
                                    length * 0.75
                                }
                                .transition(.opacity)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollIndicators(.hidden)
                .contentMargins(.horizontal, 24, for: .scrollContent)
            }
        }
    }

    /// Spectator-quiz invitation as a carousel card. Dismissible per session;
    /// shows a lock (→ paywall) for Free users, retake copy once completed.
    private var quizCard: some View {
        HStack(spacing: 10) {
            Button {
                if isPremium {
                    showQuiz = true
                } else {
                    showPaywall = true
                }
            } label: {
                HStack(spacing: 10) {
                    Group {
                        if EmojiSupport.isAvailable {
                            Text("\u{1F3AD}")
                                .font(.system(size: 15))
                        } else {
                            Image(systemName: "theatermasks.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 30, height: 30)
                    .background(.white.opacity(0.22), in: .circle)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(L("quiz.banner.title"))
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(isPremium
                            ? (quiz.profile == nil ? L("quiz.banner.sub") : L("quiz.banner.retake"))
                            : L("premium.locked"))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    Image(systemName: isPremium ? "chevron.right" : "lock.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .light), trigger: showQuiz)

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    quizBannerHidden = true
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 22, height: 22)
                    .background(.white.opacity(0.18), in: .circle)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L("common.close"))
        }
        .padding(.horizontal, 12)
        .frame(height: 56)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Theme.primary, Theme.rose],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: 16)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Theme.primary.opacity(0.18), radius: 5, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(L("quiz.banner.title")). \(isPremium ? (quiz.profile == nil ? L("quiz.banner.sub") : L("quiz.banner.retake")) : L("premium.locked"))")
    }
}

/// Compact gradient card of the featured carousel.
struct FeaturedCardView: View {
    let collection: FeaturedCollection

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if EmojiSupport.isAvailable {
                    Text(collection.emoji)
                        .font(.system(size: 15))
                } else {
                    Image(systemName: collection.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 30, height: 30)
            .background(.white.opacity(0.22), in: .circle)

            VStack(alignment: .leading, spacing: 1) {
                Text(collection.title)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(collection.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 12)
        .frame(height: 56)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: collection.gradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: 16)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: (collection.gradient.first ?? .black).opacity(0.18), radius: 5, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(collection.title). \(collection.subtitle)")
    }
}

#Preview {
    NavigationStack {
        ZStack {
            Theme.background.ignoresSafeArea()
            FeaturedStripView(
                showQuiz: .constant(false),
                showPaywall: .constant(false),
                quizBannerHidden: .constant(false)
            )
        }
    }
    .environment(QuizStore())
}
