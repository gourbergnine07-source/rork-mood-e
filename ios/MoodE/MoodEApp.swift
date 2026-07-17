//
//  MoodEApp.swift
//  MoodE
//
//  Created by Rork on July 17, 2026.
//

import SwiftUI

@main
struct MoodEApp: App {
    @State private var library = MovieLibrary()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(library)
        }
    }
}
