//
//  MoodSelection.swift
//  MoodE
//

import SwiftUI

/// Emotional state chosen in step 1.
enum Mood: String, CaseIterable, Identifiable, Hashable {
    case felice, triste, stressato, annoiato, innamorato, nostalgico
    case arrabbiato, motivato, malinconico, spensierato, curioso, impaurito

    var id: String { rawValue }

    var title: String {
        switch self {
        case .felice: return "Felice"
        case .triste: return "Triste"
        case .stressato: return "Stressato"
        case .annoiato: return "Annoiato"
        case .innamorato: return "Innamorato"
        case .nostalgico: return "Nostalgico"
        case .arrabbiato: return "Arrabbiato"
        case .motivato: return "Motivato"
        case .malinconico: return "Malinconico"
        case .spensierato: return "Spensierato"
        case .curioso: return "Curioso"
        case .impaurito: return "Impaurito"
        }
    }

    var emoji: String {
        switch self {
        case .felice: return "😊"
        case .triste: return "😢"
        case .stressato: return "😰"
        case .annoiato: return "🥱"
        case .innamorato: return "😍"
        case .nostalgico: return "🕰️"
        case .arrabbiato: return "😡"
        case .motivato: return "💪"
        case .malinconico: return "🌧️"
        case .spensierato: return "🦋"
        case .curioso: return "🤔"
        case .impaurito: return "😨"
        }
    }

    var icon: String {
        switch self {
        case .felice: return "sun.max"
        case .triste: return "cloud.rain"
        case .stressato: return "wind"
        case .annoiato: return "zzz"
        case .innamorato: return "heart"
        case .nostalgico: return "clock.arrow.circlepath"
        case .arrabbiato: return "flame"
        case .motivato: return "bolt"
        case .malinconico: return "cloud.drizzle"
        case .spensierato: return "leaf"
        case .curioso: return "sparkle.magnifyingglass"
        case .impaurito: return "moon.stars"
        }
    }

    /// Signature color of each emotion, used for card backgrounds and accents.
    var tint: Color {
        switch self {
        case .felice: return Color(red: 0.94, green: 0.70, blue: 0.16)
        case .triste: return Color(red: 0.36, green: 0.56, blue: 0.86)
        case .stressato: return Color(red: 0.27, green: 0.61, blue: 0.62)
        case .annoiato: return Color(red: 0.62, green: 0.56, blue: 0.85)
        case .innamorato: return Color(red: 0.93, green: 0.42, blue: 0.61)
        case .nostalgico: return Color(red: 0.71, green: 0.52, blue: 0.28)
        case .arrabbiato: return Color(red: 0.88, green: 0.35, blue: 0.29)
        case .motivato: return Color(red: 0.94, green: 0.54, blue: 0.18)
        case .malinconico: return Color(red: 0.47, green: 0.54, blue: 0.75)
        case .spensierato: return Color(red: 0.31, green: 0.69, blue: 0.49)
        case .curioso: return Color(red: 0.57, green: 0.42, blue: 0.83)
        case .impaurito: return Color(red: 0.38, green: 0.38, blue: 0.72)
        }
    }
}

/// What the user wants to get from the movie, chosen in step 2.
enum ViewingGoal: String, CaseIterable, Identifiable, Hashable {
    case ridere, piangere, rilassarmi, riflettere, emozionarmi
    case distrarmi, ispirarmi, paura, sognare, innamorarmi

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ridere: return "Ridere"
        case .piangere: return "Piangere / sfogarmi"
        case .rilassarmi: return "Rilassarmi"
        case .riflettere: return "Riflettere"
        case .emozionarmi: return "Emozionarmi"
        case .distrarmi: return "Distrarmi"
        case .ispirarmi: return "Sentirmi ispirato"
        case .paura: return "Avere paura / brivido"
        case .sognare: return "Sognare / evadere"
        case .innamorarmi: return "Innamorarmi della storia"
        }
    }

    var emoji: String {
        switch self {
        case .ridere: return "😂"
        case .piangere: return "😭"
        case .rilassarmi: return "🧘"
        case .riflettere: return "💭"
        case .emozionarmi: return "💓"
        case .distrarmi: return "🎈"
        case .ispirarmi: return "✨"
        case .paura: return "👻"
        case .sognare: return "🌌"
        case .innamorarmi: return "💘"
        }
    }

    var icon: String {
        switch self {
        case .ridere: return "face.smiling"
        case .piangere: return "drop"
        case .rilassarmi: return "water.waves"
        case .riflettere: return "brain.head.profile"
        case .emozionarmi: return "waveform.path.ecg"
        case .distrarmi: return "party.popper"
        case .ispirarmi: return "lightbulb"
        case .paura: return "theatermasks"
        case .sognare: return "sparkles"
        case .innamorarmi: return "heart.text.square"
        }
    }

    /// Signature color of each goal, used for card backgrounds and accents.
    var tint: Color {
        switch self {
        case .ridere: return Color(red: 0.94, green: 0.69, blue: 0.15)
        case .piangere: return Color(red: 0.38, green: 0.58, blue: 0.87)
        case .rilassarmi: return Color(red: 0.32, green: 0.69, blue: 0.54)
        case .riflettere: return Color(red: 0.56, green: 0.44, blue: 0.83)
        case .emozionarmi: return Color(red: 0.92, green: 0.44, blue: 0.62)
        case .distrarmi: return Color(red: 0.94, green: 0.55, blue: 0.21)
        case .ispirarmi: return Color(red: 0.88, green: 0.64, blue: 0.14)
        case .paura: return Color(red: 0.40, green: 0.38, blue: 0.72)
        case .sognare: return Color(red: 0.51, green: 0.46, blue: 0.88)
        case .innamorarmi: return Color(red: 0.87, green: 0.37, blue: 0.51)
        }
    }
}

/// Preferred movie era, chosen in step 3.
enum MovieEra: String, CaseIterable, Identifiable, Hashable {
    case seventiesEighties, nineties, twoThousands, lastFiveYears, noPreference

    var id: String { rawValue }

    var title: String {
        switch self {
        case .seventiesEighties: return "Anni '70–'80"
        case .nineties: return "Anni '90"
        case .twoThousands: return "Anni 2000–2010"
        case .lastFiveYears: return "Ultimi 5 anni"
        case .noPreference: return "Non ho preferenze"
        }
    }

    var emoji: String {
        switch self {
        case .seventiesEighties: return "📼"
        case .nineties: return "💿"
        case .twoThousands: return "📱"
        case .lastFiveYears: return "🍿"
        case .noPreference: return "🎬"
        }
    }

    var subtitle: String {
        switch self {
        case .seventiesEighties: return "Grandi classici e cult"
        case .nineties: return "L'epoca d'oro del cinema pop"
        case .twoThousands: return "Storie moderne e memorabili"
        case .lastFiveYears: return "Le uscite più recenti"
        case .noPreference: return "Sorprendimi con qualsiasi epoca"
        }
    }

    /// Signature color of each era, used for row backgrounds and accents.
    var tint: Color {
        switch self {
        case .seventiesEighties: return Color(red: 0.71, green: 0.52, blue: 0.28)
        case .nineties: return Color(red: 0.57, green: 0.44, blue: 0.83)
        case .twoThousands: return Color(red: 0.36, green: 0.57, blue: 0.86)
        case .lastFiveYears: return Color(red: 0.88, green: 0.43, blue: 0.28)
        case .noPreference: return Color(red: 0.29, green: 0.62, blue: 0.61)
        }
    }
}

/// The three choices made in the guided flow, passed to the results screen.
struct MoodSelection: Hashable {
    let mood: Mood
    let goal: ViewingGoal
    let era: MovieEra
}
