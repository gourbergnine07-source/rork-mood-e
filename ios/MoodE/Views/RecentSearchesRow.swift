//
//  RecentSearchesRow.swift
//  MoodE
//

import SwiftUI

/// Horizontal chips with the user's last searches (max 5, stored only on
/// device) shown under a search bar. Shared by the TV series section and
/// the Al Cinema movie search.
struct RecentSearchesRow: View {
    let history: SearchHistory
    var tint: Color = Theme.primary
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(L("search.recent"), systemImage: "clock.arrow.circlepath")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.inkSoft)

                Spacer(minLength: 0)

                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        history.clear()
                    }
                } label: {
                    Text(L("search.clear"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint)
                }
                .accessibilityLabel(L("search.clear"))
            }
            .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(history.items, id: \.self) { term in
                        Button {
                            onSelect(term)
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 10, weight: .semibold))
                                Text(term)
                                    .font(.footnote.weight(.medium))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Theme.card, in: .capsule)
                            .overlay(
                                Capsule()
                                    .stroke(tint.opacity(0.20), lineWidth: 1)
                            )
                        }
                        .buttonStyle(PressableCardStyle())
                        .accessibilityLabel(LF("search.a11y.recent", term))
                    }
                }
            }
            .contentMargins(.horizontal, 24)
        }
    }
}
