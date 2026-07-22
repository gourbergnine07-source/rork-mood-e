# Mood-E 🎬

**Il film giusto per il tuo umore.**

Mood-E è un'app iOS nativa che consiglia film in base a come ti senti. Scegli un'emozione, un obiettivo e un'epoca — Mood-E fa il resto: niente scroll infinito, solo il film perfetto per stasera.

📲 [Scarica dall'App Store](https://apps.apple.com/app/id6792271949)

---

## Funzionalità

### Core
- **Mood Flow** — percorso guidato emozione → obiettivo → epoca che porta a consigli su misura (dati TMDB)
- **Sorprendimi** — un film a sorpresa quando non sai cosa scegliere
- **Cinema & Tendenze** — film in sala, in arrivo e di tendenza
- **Dove guardarlo** — piattaforme di streaming disponibili per ogni film
- **Trailer, condivisione e liste** — la tua videoteca personale con visti e da vedere

### Diario & Community
- **Diario dell'umore** — check-in giornalieri con statistiche, streak e ricordi ("Un anno fa oggi")
- **Amici** — confronta le statistiche da cinefilo con i tuoi amici tramite codice amico
- **Invita amici** — link personale condivisibile con landing page e deep link nell'app
- **Bacheca consigli** — suggerimenti dalla community
- **Sfide mensili** — obiettivi a tema per veri cinefili

### Premium ⭐
- Nessuna pubblicità
- Sfida un amico e Serata in Duo
- Sync su cloud (iCloud/CloudKit)
- Icone alternative e temi
- Quiz "Che spettatore sei?"
- Comandi Siri

### Extra
- **Widget** per la schermata Home (film del giorno, mood rapido)
- **Localizzazione completa** in 🇮🇹 italiano, 🇬🇧 inglese, 🇪🇸 spagnolo e 🇫🇷 francese
- **Deep link** `moode://` per widget e inviti

---

## Tecnologie

| Area | Stack |
|------|-------|
| App iOS | Swift 6 · SwiftUI · MVVM · iOS 18+ |
| Dati film | [TMDB API](https://www.themoviedb.org/) |
| Backend | Supabase (auth cloud sync, amici, Serata in Duo) |
| Edge functions | Cloudflare Workers (bacheca consigli, pagina inviti) |
| Abbonamenti | RevenueCat + StoreKit |
| Monetizzazione free | AdMob + link affiliati |
| Widget | WidgetKit |

---

## Struttura del progetto

```
├── ios/                  # App iOS nativa (Swift/SwiftUI)
│   ├── MoodE/
│   │   ├── Views/        # Schermate SwiftUI (Home, Diario, Community, ...)
│   │   ├── ViewModels/   # Logica di presentazione (MVVM)
│   │   ├── Models/       # Modelli dati
│   │   ├── Services/     # TMDB, Supabase, RevenueCat, sync, analytics
│   │   ├── Utilities/    # Helper ed estensioni
│   │   └── Resources/    # Localizzazioni it/en/es/fr
│   ├── MoodEWidget/      # Widget per la schermata Home
│   └── metadata/         # Metadati App Store
├── functions/            # Cloudflare Workers (bacheca consigli, invite page)
├── backend/              # Tipi e schema Supabase
├── docs/                 # Privacy policy e termini
└── screenshots/          # Screenshot App Store ×4 lingue
```

---

## Privacy

- Nessun account richiesto per usare l'app: il login è opzionale, solo per il backup cloud
- Eliminazione account e dati cloud direttamente dall'app
- [Privacy Policy](docs/privacy-policy.html) · [Termini di servizio](docs/termini.html)

---

Costruito con ❤️ e [Rork](https://rork.app).
