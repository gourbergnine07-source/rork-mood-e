//
//  MonetizationInfoView.swift
//  MoodE
//

import SwiftUI

/// "Come guadagniamo": short transparency page explaining the two
/// revenue sources of the app — advertising and affiliate links.
struct MonetizationInfoView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(L("monetization.intro"))
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
                    .lineSpacing(4)

                infoCard(
                    icon: "megaphone.fill",
                    tint: Theme.primary,
                    title: L("monetization.ads.title"),
                    body: L("monetization.ads.body")
                )

                infoCard(
                    icon: "cart.fill",
                    tint: Theme.seenGreen,
                    title: L("monetization.affiliate.title"),
                    body: L("monetization.affiliate.body")
                )

                Text(L("monetization.footer"))
                    .font(.caption)
                    .italic()
                    .foregroundStyle(Theme.inkSoft.opacity(0.85))
                    .lineSpacing(3)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(L("monetization.title"))
        .toolbarTitleDisplayMode(.inline)
    }

    private func infoCard(icon: String, tint: Color, title: String, body text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(tint, in: .rect(cornerRadius: 8))

                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.ink)
            }

            Text(text)
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
                .lineSpacing(4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: .rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(tint.opacity(0.15), lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack {
        MonetizationInfoView()
    }
}
