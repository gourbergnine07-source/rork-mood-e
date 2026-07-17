//
//  CinemaView.swift
//  MoodE
//

import SwiftUI

/// Al Cinema tab: will show movies now playing near the user's location.
struct CinemaView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack {
                    Spacer()
                    PlaceholderCard(
                        icon: "popcorn",
                        title: "Ora al cinema",
                        message: "Scopri i film in sala vicino a te: useremo la tua posizione per mostrarti cosa c'è nei cinema della tua zona."
                    )
                    Spacer()
                }
            }
            .navigationTitle("Al Cinema")
            .toolbarTitleDisplayMode(.large)
        }
        .tint(Theme.primary)
    }
}

#Preview {
    CinemaView()
}
