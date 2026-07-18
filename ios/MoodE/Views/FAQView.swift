//
//  FAQView.swift
//  MoodE
//

import SwiftUI

/// One FAQ entry shown in the in-app help page.
struct FAQItem: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
}

/// In-app "Domande frequenti" page: native expandable Q&A list.
struct FAQView: View {
    @State private var expandedId: UUID?

    /// Computed so questions and answers re-localize on language change.
    private var items: [FAQItem] {
        (1...8).map { index in
            FAQItem(
                question: L("faq.q\(index)"),
                answer: L("faq.a\(index)")
            )
        }
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(items) { item in
                        FAQCard(
                            item: item,
                            isExpanded: expandedId == item.id
                        ) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                expandedId = expandedId == item.id ? nil : item.id
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(L("faq.title"))
        .toolbarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: expandedId)
    }
}

/// Expandable question/answer card.
private struct FAQCard: View {
    let item: FAQItem
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 12) {
                    Text(item.question)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.tabSettings)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }

                if isExpanded {
                    Text(item.answer)
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                        .lineSpacing(3)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 10)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(16)
            .background(Theme.card, in: .rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.tabSettings.opacity(isExpanded ? 0.25 : 0.10), lineWidth: 1)
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(isExpanded ? L("faq.a11y.close") : L("faq.a11y.open"))
    }
}

#Preview {
    NavigationStack {
        FAQView()
    }
}
