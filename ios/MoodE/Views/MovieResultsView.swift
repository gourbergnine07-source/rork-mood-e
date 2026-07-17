//
//  MovieResultsView.swift
//  MoodE
//

import SwiftUI

/// Results screen: receives the flow choices. TMDB integration coming next.
struct MovieResultsView: View {
    let selection: MoodSelection

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    recap

                    PlaceholderCard(
                        icon: "film.stack",
                        title: "I tuoi film in arrivo",
                        message: "Qui appariranno i film scelti su misura per te da TMDB, in base alle tue risposte."
                    )
                }
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Il tuo film")
        .toolbarTitleDisplayMode(.inline)
        .tint(Theme.primary)
    }

    private var recap: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Le tue scelte")
                .font(.headline)
                .foregroundStyle(Theme.ink)

            recapRow(emoji: selection.mood.emoji, label: "Emozione", value: selection.mood.title)
            recapRow(emoji: selection.goal.emoji, label: "Obiettivo", value: selection.goal.title)
            recapRow(emoji: selection.era.emoji, label: "Epoca", value: selection.era.title)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.65), in: .rect(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Theme.primary.opacity(0.10), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }

    private func recapRow(emoji: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Text(emoji)
                .font(.system(size: 22))
                .frame(width: 40, height: 40)
                .background(Theme.primary.opacity(0.08), in: .rect(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.inkSoft)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
            }
        }
    }
}

#Preview {
    NavigationStack {
        MovieResultsView(
            selection: MoodSelection(mood: .felice, goal: .ridere, era: .nineties)
        )
    }
}
