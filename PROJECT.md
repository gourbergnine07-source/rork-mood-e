# PROJECT.md — Mood-E

> File di memoria del progetto. Ogni IA (Rork, Claude o altre) lo legge **prima** di ogni compito e lo aggiorna **alla fine**.

## Istruzioni per l'IA (leggere sempre)
- Leggi tutto questo file prima di ogni compito. Per i social leggi anche `SOCIAL.md`.
- Un compito alla volta. Prima di modificare, elenca i file che cambierai.
- Se qualcosa non è chiaro, **chiedi**. Non indovinare.
- Non toccare codice che funziona fuori dal compito richiesto. Non cancellare funzioni esistenti.
- Niente nuove librerie o servizi senza approvazione.
- Mantieni sempre le 6 lingue allineate (it, en, es, fr, de, pt): ogni nuovo testo va in tutti i file di `Resources/*.json`.
- Prima di proporre una funzione, controlla che non esista già nel codice.
- Alla fine: aggiorna **Stato attuale**, **Decisioni** e **Changelog** qui sotto, e dimmi come testare la modifica.

## Identità
- **Cosa fa:** consiglia film e serie in base all'umore (emozione → obiettivo → epoca), con diario dell'umore, liste, community e quiz.
- **Per chi:** chi non sa cosa guardare stasera e vuole evitare lo scroll infinito.
- **Piattaforma:** iOS 18+ (App Store, ID 6792271949). Widget per la Home.
- **Lingue:** italiano, inglese, spagnolo, francese, tedesco, portoghese.
- **Monetizzazione:** Premium in abbonamento (RevenueCat + StoreKit) — €1/mese, €6/anno; versione gratuita con AdMob e link affiliati Amazon.

## Stack e architettura
- **App:** Swift 6 · SwiftUI · MVVM — cartella `ios/MoodE/`
  - `Views/` schermate · `ViewModels/` logica · `Models/` dati · `Services/` servizi · `Utilities/` helper · `Resources/` lingue e pagine legali
- **Widget:** `ios/MoodEWidget/` (WidgetKit)
- **Dati film/serie:** TMDB API (`TMDBService`, `TMDBCache`, `WatchProviderCache`)
- **Backend:** Supabase (`backend/`) — sync cloud, amici, Serata in Duo, tabella `app_release_config`
- **Edge functions:** Cloudflare Workers (`functions/`) — bacheca consigli, pagina inviti, moderazione, stati
- **Abbonamenti:** RevenueCat (`PremiumStore`, `PaywallView`)
- **Pubblicità:** AdMob (`AdsManager`, `NativeAdManager`); affiliati: `AffiliateLinkService`
- **Deep link:** `moode://` (widget e inviti)
- **Sito/landing e pagine legali:** `docs/` (6 lingue)

## Regole di codice
- Segui lo stile esistente (SwiftUI, MVVM, servizi separati).
- Avviso aggiornamento: si gestisce da Supabase (`app_release_config`), **mai** cablato nel codice; il blocco (`minimum_required_version`) solo per rotture tecniche reali.
- Le funzioni Premium restano Premium: non sbloccarle per errore.
- Nessun login obbligatorio: il login serve solo per il backup cloud.
- **Da non toccare senza chiedere:** prezzi e prodotti RevenueCat, ID AdMob, `app-ads.txt`, deep link, privacy policy.

## Stato attuale
- Versione nel codice: **1.6** (ultimo aggiornamento del repo: 16/10/2026).
- Funzioni presenti (verificate nel codice): vedi `README.md` e l'elenco in `SOCIAL.md`.
- Problemi risolti in passato: `app-ads.txt`, crash del deep link all'avvio a freddo, notifiche push non cliccabili, link affiliati Amazon che aprivano la pagina sbagliata.
- In corso: marketing (Reddit, Google Ads, Apple Search Ads, social).

## Decisioni (data — decisione — motivo)
- 2026 — Prezzo Premium €1/mese e €6/anno — prezzo basso per convertire di più.
- 2026 — Avviso aggiornamento remoto via Supabase — cambiare messaggio senza nuova build né revisione.
- 2026 — Prima di aggiungere contenuti (es. quiz), verificare quelli esistenti — evitare doppioni.

## Changelog
- 05/11/2026 — Creati `PROJECT.md` e `SOCIAL.md` (memoria del progetto per le IA).
