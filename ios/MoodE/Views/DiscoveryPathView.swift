//
//  DiscoveryPathView.swift
//  MoodE
//

import SwiftUI

/// Renders the mood → goal → era path that led the user to a movie.
///
/// Three presentations of the very same data:
/// - `.expandable`: collapsed "Come l'hai trovato" row used on list cards,
///   so the card stays compact until the user asks for the detail;
/// - `.panel`: discreet framed block shown in the movie detail page;
/// - `.compact`: single always-visible line for the memories gallery.
struct DiscoveryPathView: View {
    enum Style {
        case expandable
        case panel
        case compact
    }

    let path: DiscoveryPath
    var style: Style = .compact
    var tint: Color = Theme.primary

    @State private var isExpanded: Bool = false

    var body: some View {
        if path.isRenderable {
            switch style {
            case .expandable: expandable
            case .panel: panel
            case .compact: compact
            }
        }
    }

    // MARK: - Presentations

    /// Tappable summary row: the arrow rotates and the path slides open.
    private var expandable: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9, weight: .semibold))
                    Text(L("discovery.how"))
                        .font(.caption2.weight(.semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(tint)
                .padding(.vertical, 3)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L("discovery.how"))
            .accessibilityValue(path.plainText)

            if isExpanded {
                pathText(size: .caption2)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(tint.opacity(0.08), in: .rect(cornerRadius: 11))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11)
                            .stroke(tint.opacity(0.18), lineWidth: 1)
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
        .sensoryFeedback(.selection, trigger: isExpanded)
    }

    /// Detail page block: sits right under the save / seen buttons.
    private var panel: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                Text(L("discovery.how"))
                    .font(.footnote.weight(.bold))
            }
            .foregroundStyle(tint)

            pathText(size: .footnote)

            Text(L("discovery.hint"))
                .font(.caption2)
                .foregroundStyle(Theme.inkSoft.opacity(0.85))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(tint.opacity(0.16), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(L("discovery.how")): \(path.plainText)")
    }

    /// Memories gallery: one quiet line next to rating and comment.
    private var compact: some View {
        HStack(alignment: .top, spacing: 5) {
            Image(systemName: "sparkles")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(tint)
                .padding(.top, 2)
            pathText(size: .caption2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(L("discovery.how")): \(path.plainText)")
    }

    // MARK: - Path rendering

    /// Concatenated `Text` so each hop keeps its own signature color while
    /// the whole path still wraps naturally over several lines.
    private func pathText(size: Font.TextStyle) -> some View {
        let steps = path.steps
        var result = Text("")
        for (index, step) in steps.enumerated() {
            if index > 0 {
                result = result + Text("  →  ")
                    .foregroundStyle(Theme.inkSoft.opacity(0.6))
            }
            result = result + Text("\(step.emoji) ")
            result = result + Text(step.title)
                .foregroundStyle(step.tint)
                .fontWeight(.semibold)
        }
        return result
            .font(.system(size == .footnote ? .footnote : .caption2))
            .lineSpacing(3)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    VStack(spacing: 20) {
        DiscoveryPathView(
            path: DiscoveryPath(
                selection: MoodSelection(mood: .felice, goal: .emozionarmi, era: .lastFiveYears)
            ),
            style: .panel
        )
        DiscoveryPathView(
            path: DiscoveryPath(
                selection: MoodSelection(mood: .nostalgico, goal: .sognare, eras: [.nineties, .twoThousands])
            ),
            style: .expandable,
            tint: Theme.tabList
        )
        DiscoveryPathView(
            path: DiscoveryPath(
                selection: MoodSelection(mood: .triste, goal: .piangere, era: .noPreference)
            )
        )
    }
    .padding(24)
    .background(Theme.background)
}
