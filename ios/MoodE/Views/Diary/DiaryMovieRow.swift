//
//  DiaryMovieRow.swift
//  MoodE
//

import SwiftUI

/// Role of a movie reference inside a diary day: it only drives the accent
/// color and the leading marker, never the behaviour.
enum DiaryMovieRole {
    case scheduled
    case proposed
    case watched

    var accent: Color {
        switch self {
        case .scheduled: return Theme.rose
        case .proposed: return Theme.primary
        case .watched: return Theme.seenGreen
        }
    }

    var icon: String {
        switch self {
        case .scheduled: return "movieclapper"
        case .proposed: return "sparkles"
        case .watched: return "checkmark.circle.fill"
        }
    }
}

/// One movie referenced by a diary day. The title is always a link to the
/// shared movie detail page and the "..." menu removes the reference from
/// that single day. Planned, proposed and already-watched movies all use
/// this row, so every title in the diary looks and behaves the same.
struct DiaryMovieRow: View {
    let movie: TMDBMovie
    let role: DiaryMovieRole
    /// Optional trailing badge, e.g. the emoji rating of a memory.
    var badge: String?
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            NavigationLink(value: movie) {
                HStack(spacing: 6) {
                    Image(systemName: role.icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(role.accent)

                    Text(movie.title)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Theme.ink)
                        .underline(true, color: role.accent.opacity(0.45))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let badge {
                        Text(badge)
                            .font(.system(size: 13))
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(role.accent.opacity(0.75))

                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(DiaryLinkButtonStyle(accent: role.accent))
            .accessibilityHint(L("diary.movie.open"))

            DiaryMovieMenu(onDelete: onDelete)
        }
    }
}

/// The "..." menu shared by every movie reference in the diary.
struct DiaryMovieMenu: View {
    let onDelete: () -> Void

    var body: some View {
        Menu {
            Button(role: .destructive, action: onDelete) {
                Label(L("diary.movie.remove.confirm"), systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
                .frame(width: 30, height: 30)
                .background(Theme.surface.opacity(0.85), in: .circle)
                .contentShape(.circle)
        }
        .accessibilityLabel(L("diary.movie.options"))
    }
}

/// Press feedback for diary movie titles: a soft tinted highlight so the
/// tappable nature is obvious at a glance, without extra chrome.
struct DiaryLinkButtonStyle: ButtonStyle {
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(
                accent.opacity(configuration.isPressed ? 0.12 : 0),
                in: .rect(cornerRadius: 8)
            )
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
