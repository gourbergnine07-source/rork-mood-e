//
//  HomeView.swift
//  MoodE
//

import SwiftUI

/// Home tab: hosts the guided emotion → goal → era flow.
struct HomeView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                MoodFlowView()
            }
            .navigationTitle("Mood-E")
            .toolbarTitleDisplayMode(.inline)
        }
        .tint(Theme.primary)
    }
}

#Preview {
    HomeView()
}
