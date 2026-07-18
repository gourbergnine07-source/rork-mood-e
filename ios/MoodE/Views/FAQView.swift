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

    private let items: [FAQItem] = [
        FAQItem(
            question: "Come funzionano i consigli sui film?",
            answer: "Scegli come ti senti, cosa vuoi ottenere dal film e l'epoca che preferisci: Mood-E combina queste scelte e interroga il database di TMDB per proporti fino a 15 film adatti al tuo stato d'animo. Con \"Nuove proposte\" ricevi altri titoli con gli stessi filtri."
        ),
        FAQItem(
            question: "I film che ho già visto continuano a comparire?",
            answer: "No. Quando segni un film come \"Già visto\", viene escluso automaticamente dai consigli della Home e dalle Tendenze. Puoi rivedere l'elenco dei film visti nella tab \"La mia lista\"."
        ),
        FAQItem(
            question: "Dove viene salvata la mia lista?",
            answer: "Tutto resta sul tuo iPhone: la watchlist e i film già visti sono salvati solo in locale. Non serve alcun account e nessun dato viene inviato a server esterni."
        ),
        FAQItem(
            question: "Come attivo le notifiche sulle nuove uscite?",
            answer: "Vai in Impostazioni e attiva l'interruttore \"Nuove uscite e film al cinema\". Riceverai un avviso quando arrivano nuovi film su TMDB e il giorno in cui un film esce nelle sale. Puoi disattivarle quando vuoi dallo stesso interruttore."
        ),
        FAQItem(
            question: "Perché \"Al Cinema\" chiede la mia posizione?",
            answer: "La posizione serve solo a mostrarti i film in sala nel tuo paese e i cinema vicini a te tramite Apple Maps. Puoi rifiutare con \"Non ora\": in quel caso viene usato il paese impostato sul tuo iPhone."
        ),
        FAQItem(
            question: "I trailer si aprono fuori dall'app?",
            answer: "No, i trailer si riproducono sempre dentro Mood-E in una finestra dedicata, senza mai lasciare l'app."
        ),
        FAQItem(
            question: "Da dove arrivano i dati sui film?",
            answer: "Titoli, poster, valutazioni e trailer sono forniti da The Movie Database (TMDB). Questa app utilizza dati TMDB ma non è approvata o certificata da TMDB."
        ),
        FAQItem(
            question: "Ho trovato un problema: come lo segnalo?",
            answer: "Dalla sezione \"Supporto e assistenza\" nelle Impostazioni tocca \"Segnala un problema\": si aprirà la pagina GitHub dove puoi descrivere il problema o richiedere una nuova funzione. Ti risponderemo il prima possibile."
        )
    ]

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
        .navigationTitle("Domande frequenti")
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
        .accessibilityHint(isExpanded ? "Tocca per chiudere la risposta" : "Tocca per leggere la risposta")
    }
}

#Preview {
    NavigationStack {
        FAQView()
    }
}
