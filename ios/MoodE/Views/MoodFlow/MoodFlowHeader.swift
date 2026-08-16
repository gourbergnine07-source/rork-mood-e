//
//  MoodFlowHeader.swift
//  MoodE
//
//  Step-1 header, extracted from MoodFlowView to keep type-checking fast.
//

import SwiftUI

/// Step-1 header: featured icon strip (collections, live events and the
/// quiz), today's quiz suggestion, plus the occasional anniversary card.
/// Kept intentionally short so the emotion grid stays visible without
/// scrolling — each card here shows up only when it has something to say.
struct MoodFlowHeader: View {
    @Binding var showQuiz: Bool
    @Binding var showPaywall: Bool
    @Binding var quizBannerHidden: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FeaturedStripView(
                showQuiz: $showQuiz,
                showPaywall: $showPaywall,
                quizBannerHidden: $quizBannerHidden
            )

            DailyQuizCard()
                .padding(.horizontal, 24)

            AnniversaryCard()
                .padding(.horizontal, 24)
        }
    }
}
