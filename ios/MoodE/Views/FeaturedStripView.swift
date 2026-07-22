//
//  FeaturedStripView.swift
//  MoodE
//

import SwiftUI

/// "In evidenza" strip at the top of Home: a single ultra-thin row of small
/// gradient icon buttons (one per active editorial collection, plus the
/// spectator quiz). Each icon carries a tiny caption underneath; the full
/// title/subtitle appears in a context menu on long press. Designed so the
/// whole row is barely taller than a line of text and Home never scrolls.
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
                    HStack(alignment: .top, spacing: FeaturedCardMetrics.gutter) {
                        ForEach(collections) { collection in
                            NavigationLink(value: collection) {
                                FeaturedCardView(collection: collection)
                            }
                            .buttonStyle(PressableCardStyle())
                            // Long-press tooltip with the full title + subtitle.
                            .contextMenu {
                                Section("\(collection.title) — \(collection.subtitle)") {
                                    NavigationLink(value: collection) {
                                        Label(L("common.open"), systemImage: "arrow.right.circle")
                                    }
                                }
                            }
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

    /// Spectator-quiz invitation as a small icon button, identical in shape
    /// to the collection icons; the lock badge (→ paywall) is the only
    /// difference for Free users. Long press offers the hide action.
    private var quizCard: some View {
        Button {
            if isPremium {
                showQuiz = true
            } else {
                showPaywall = true
            }
        } label: {
            VStack(spacing: FeaturedCardMetrics.captionSpacing) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Theme.primary, Theme.rose],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: FeaturedCardMetrics.iconSize, height: FeaturedCardMetrics.iconSize)
                        .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))

                    if EmojiSupport.isAvailable {
                        Text("\u{1F3AD}")
                            .font(.system(size: 13))
                    } else {
                        Image(systemName: "theatermasks.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    if !isPremium {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 13, height: 13)
                            .background(Theme.ink.opacity(0.85), in: .circle)
                            .offset(x: FeaturedCardMetrics.iconSize / 2 - 4, y: FeaturedCardMetrics.iconSize / 2 - 4)
                    }
                }

                Text(L("quiz.banner.title"))
                    .font(.system(size: FeaturedCardMetrics.captionSize, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.85)
                    .frame(width: FeaturedCardMetrics.captionWidth)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .contentShape(.rect)
        }
        .buttonStyle(PressableCardStyle())
        .sensoryFeedback(.impact(weight: .light), trigger: showQuiz)
        // Long-press tooltip: full copy + hide action (replaces the old ✕).
        .contextMenu {
            Section("\(L("quiz.banner.title")) — \(isPremium ? (quiz.profile == nil ? L("quiz.banner.sub") : L("quiz.banner.retake")) : L("premium.locked"))") {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        quizBannerHidden = true
                    }
                } label: {
                    Label(L("common.close"), systemImage: "xmark")
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(L("quiz.banner.title")). \(isPremium ? (quiz.profile == nil ? L("quiz.banner.sub") : L("quiz.banner.retake")) : L("premium.locked"))")
    }
}

/// Shared sizing for the featured strip: small icon circles with a tiny
/// caption underneath, so the whole row stays about as tall as one line
/// of text plus a micro-label.
enum FeaturedCardMetrics {
    static let iconSize: CGFloat = 36
    static let captionSize: CGFloat = 11
    static let captionSpacing: CGFloat = 3
    static let captionWidth: CGFloat = 84
    static let gutter: CGFloat = 12
}

/// Small gradient icon button of the featured strip: circle + micro-caption.
/// The full title/subtitle lives in the long-press context menu applied by
/// the parent, keeping the row as slim as possible.
struct FeaturedCardView: View {
    let collection: FeaturedCollection

    var body: some View {
        VStack(spacing: FeaturedCardMetrics.captionSpacing) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: collection.gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: FeaturedCardMetrics.iconSize, height: FeaturedCardMetrics.iconSize)
                    .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))

                if EmojiSupport.isAvailable {
                    Text(collection.emoji)
                        .font(.system(size: 13))
                } else {
                    Image(systemName: collection.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .shadow(color: (collection.gradient.first ?? .black).opacity(0.18), radius: 2, y: 1)

            Text(collection.title)
                .font(.system(size: FeaturedCardMetrics.captionSize, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.85)
                .frame(width: FeaturedCardMetrics.captionWidth)
                .fixedSize(horizontal: false, vertical: true)
        }
        .contentShape(.rect)
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
