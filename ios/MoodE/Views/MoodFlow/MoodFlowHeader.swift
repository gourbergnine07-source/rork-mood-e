//
//  MoodFlowHeader.swift
//  MoodE
//
//  Step-1 header, extracted from MoodFlowView to keep type-checking fast.
//

import SwiftUI

/// Step-1 header: featured carousel (including the quiz card) plus the
/// occasional anniversary and live-event cards. Kept intentionally short so
/// the emotion grid stays visible without scrolling.
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

            AnniversaryCard()
                .padding(.horizontal, 24)

            if let upcoming = LiveEventCalendar.upcoming().first {
                LiveEventCard(event: upcoming.event, days: upcoming.days)
                    .padding(.horizontal, 24)
            }
        }
    }
}
