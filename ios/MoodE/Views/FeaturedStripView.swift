//
//  FeaturedStripView.swift
//  MoodE
//

import SwiftUI

/// "In evidenza" strip at the top of Home: horizontally scrollable compact
/// chips (icon + title only, self-sizing width, one thin row) for every
/// active editorial collection, plus the spectator-quiz invitation as the
/// last chip. Kept deliberately minimal so the whole Home fits on screen
/// without scrolling.
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
                    HStack(spacing: FeaturedCardMetrics.gutter) {
                        ForEach(collections) { collection in
                            NavigationLink(value: collection) {
                                FeaturedCardView(collection: collection)
                            }
                            .buttonStyle(PressableCardStyle())
                        }

                        if !quizBannerHidden {
                            quizCard
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

    /// Spectator-quiz invitation as a compact chip. Dismissible per session;
    /// shows a lock (→ paywall) for Free users — the only visual difference.
    private var quizCard: some View {
        HStack(spacing: 8) {
            Button {
                if isPremium {
                    showQuiz = true
                } else {
                    showPaywall = true
                }
            } label: {
                HStack(spacing: 6) {
                    Group {
                        if EmojiSupport.isAvailable {
                            Text("\u{1F3AD}")
                                .font(.system(size: 11))
                        } else {
                            Image(systemName: "theatermasks.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 20, height: 20)
                    .background(.white.opacity(0.22), in: .circle)

                    Text(L("quiz.banner.title"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    Image(systemName: isPremium ? "chevron.right" : "lock.fill")
                        .font(.system(size: 9, weight: .bold))
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
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 18, height: 18)
                    .background(.white.opacity(0.18), in: .circle)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L("common.close"))
        }
        .padding(.horizontal, 10)
        .frame(height: FeaturedCardMetrics.height)
        .background(
            LinearGradient(
                colors: [Theme.primary, Theme.rose],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .capsule
        )
        .overlay(
            Capsule()
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Theme.primary.opacity(0.12), radius: 3, y: 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(L("quiz.banner.title")). \(isPremium ? (quiz.profile == nil ? L("quiz.banner.sub") : L("quiz.banner.retake")) : L("premium.locked"))")
    }
}

/// Shared sizing for every chip in the strip: one thin fixed-height row
/// with a consistent gutter; width is self-sizing (title never truncated).
enum FeaturedCardMetrics {
    static let height: CGFloat = 34
    static let gutter: CGFloat = 8
}

/// Compact gradient chip of the featured strip: icon + full title only,
/// so the whole strip stays as slim as a single row of text.
struct FeaturedCardView: View {
    let collection: FeaturedCollection

    var body: some View {
        HStack(spacing: 6) {
            Group {
                if EmojiSupport.isAvailable {
                    Text(collection.emoji)
                        .font(.system(size: 11))
                } else {
                    Image(systemName: collection.icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 20, height: 20)
            .background(.white.opacity(0.22), in: .circle)

            Text(collection.title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 10)
        .frame(height: FeaturedCardMetrics.height)
        .background(
            LinearGradient(
                colors: collection.gradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .capsule
        )
        .overlay(
            Capsule()
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: (collection.gradient.first ?? .black).opacity(0.12), radius: 3, y: 1)
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
