//
//  MoodFlowHeader.swift
//  MoodE
//
//  Step-1 header, extracted from MoodFlowView to keep type-checking fast.
//

import SwiftUI

/// Step-1 header: featured strip + live-event countdown + quiz banner.
struct MoodFlowHeader: View {
    @Environment(QuizStore.self) private var quiz
    @Binding var showQuiz: Bool
    @Binding var quizBannerHidden: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            FeaturedStripView()

            if let upcoming = LiveEventCalendar.upcoming().first {
                LiveEventCard(event: upcoming.event, days: upcoming.days)
                    .padding(.horizontal, 24)
            }

            if !quizBannerHidden {
                quizBanner
                    .padding(.horizontal, 24)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    /// Slim, dismissible invitation to the spectator quiz.
    /// Returns at every app launch; once completed it becomes a retake pill.
    private var quizBanner: some View {
        HStack(spacing: 8) {
            Button {
                showQuiz = true
            } label: {
                HStack(spacing: 8) {
                    Text("\u{1F3AD}")
                        .font(.system(size: 15))

                    Text(L("quiz.banner.title"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)

                    Text(quiz.profile == nil ? L("quiz.banner.sub") : L("quiz.banner.retake"))
                        .font(.caption2)
                        .foregroundStyle(Theme.inkSoft)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    quizBannerHidden = true
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(width: 22, height: 22)
                    .background(Theme.surface.opacity(0.7), in: .circle)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L("common.close"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Theme.card, in: .capsule)
        .overlay(
            Capsule()
                .stroke(Theme.primary.opacity(0.18), lineWidth: 1)
        )
        .sensoryFeedback(.impact(weight: .light), trigger: showQuiz)
        .accessibilityLabel("\(L("quiz.banner.title")). \(quiz.profile == nil ? L("quiz.banner.sub") : L("quiz.banner.retake"))")
    }
}
