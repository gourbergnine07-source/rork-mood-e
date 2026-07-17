//
//  TrendingView.swift
//  MoodE
//

import SwiftUI

/// Tendenze tab: will show trending movies from TMDB.
struct TrendingView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack {
                    Spacer()
                    PlaceholderCard(
                        icon: "flame",
                        title: "Film di tendenza",
                        message: "Qui vedrai i film più popolari del momento, aggiornati ogni giorno da TMDB."
                    )
                    Spacer()
                }
            }
            .navigationTitle("Tendenze")
            .toolbarTitleDisplayMode(.large)
        }
        .tint(Theme.primary)
    }
}

#Preview {
    TrendingView()
}
