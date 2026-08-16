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
- **Localizzazione completa** in 🇮🇹 italiano, 🇬🇧 inglese, 🇪🇸 spagnolo, 🇫🇷 francese, 🇩🇪 tedesco e 🇵🇹 portoghese
- **Avviso aggiornamento** pilotato da remoto, senza pubblicare una nuova build
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
│   │   └── Resources/    # Localizzazioni it/en/es/fr/de/pt
│   ├── MoodEWidget/      # Widget per la schermata Home
│   └── metadata/         # Metadati App Store
├── functions/            # Cloudflare Workers (bacheca consigli, invite page)
├── backend/              # Tipi e schema Supabase
├── docs/                 # Privacy policy e termini
└── screenshots/          # Screenshot App Store ×6 lingue
```

---

## Avviso di aggiornamento (configurazione remota)

L'invito ad aggiornare non è scritto nel codice: l'app legge a ogni avvio la
tabella Supabase `app_release_config` (sola lettura per i client). Cambiare
quei valori è sufficiente per attivare o spegnere l'avviso — **nessuna nuova
build, nessuna review**.

| Campo | Significato |
|-------|-------------|
| `latest_version` | Versione live sull'App Store. Se l'installata è precedente → banner discreto in Home |
| `minimum_required_version` | Versione minima funzionante. Se l'installata è precedente → schermata bloccante |
| `notes` | Opzionale: `{"it": "...", "en": "..."}` sostituisce il testo del banner in quella lingua |

Dopo la pubblicazione di una nuova versione, allinea il valore:

```sql
update public.app_release_config
   set latest_version = '1.5', updated_at = now()
 where platform = 'ios';
```

Per annullare l'avviso basta riportare `latest_version` alla versione
precedente. Il blocco va usato solo per rotture tecniche reali (es. un'API
dismessa), mai per annunciare nuove funzionalità:

```sql
update public.app_release_config
   set minimum_required_version = '1.5', updated_at = now()
 where platform = 'ios';
```

Garanzie di sicurezza: un `minimum_required_version` superiore a
`latest_version` viene ridotto automaticamente (nessuno resta bloccato senza
un aggiornamento da installare), i valori malformati vengono ignorati e il
banner appare al massimo una volta al giorno.

---

## Privacy

- Nessun account richiesto per usare l'app: il login è opzionale, solo per il backup cloud
- Eliminazione account e dati cloud direttamente dall'app
- [Privacy Policy](docs/privacy-policy.html) · [Termini di servizio](docs/termini.html)

---

Costruito con ❤️ e [Rork](https://rork.app).
