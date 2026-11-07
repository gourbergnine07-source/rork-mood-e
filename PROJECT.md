# PROJECT.md — Mood-E

> File di memoria del progetto. Ogni IA (Rork, Claude o altre) lo legge **prima** di ogni compito e lo aggiorna **alla fine**.

## Istruzioni per l'IA (leggere sempre)
- Leggi tutto questo file prima di ogni compito. Per i social leggi anche `SOCIAL.md`.
- Un compito alla volta. Prima di modificare, elenca i file che cambierai.
- Se qualcosa non è chiaro, **chiedi**. Non indovinare.
- **Solo il compito richiesto.** Tocca e modifica solo i file necessari a questo compito. Tutto ciò che non riguarda il compito non si tocca né si modifica senza il mio consenso esplicito, anche se sembra un miglioramento. Se noti un problema fuori dal compito, segnalalo e chiedi prima di fare qualsiasi cosa.
- Niente build, invii in revisione o modifiche su App Store Connect / Google Play Console senza il mio consenso.
- Non cancellare funzioni esistenti.
- Mai inventare rotte, variabili d'ambiente, tabelle, componenti, API o librerie che non esistono nel progetto: in caso di dubbio controlla il codice esistente.
- Quando lavori sulla logica, lascia intatta l'interfaccia, salvo richiesta esplicita. Mantieni struttura dei file e nomi esistenti; codice modulare (interfaccia, servizi e logica separati).
- Niente nuove librerie o servizi senza approvazione.
- Rete: gestisci sempre errori e offline con un messaggio visibile all'utente.
- Commenti solo sulle parti non banali (acquisti in-app, SDK esterni, calcoli complessi).
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
- Fix 07/11/2026: la sincronizzazione non elimina più dal cloud i check-in del diario assenti sul dispositivo (prima un apparecchio cancellava quelli creati sull'altro, e con molti check-in la query falliva e bloccava la sync).
- 07/11/2026: le 2 funzioni AI (analisi testo umore, scan poster) passano dal Worker `functions/` (`POST /ai/mood`, `POST /ai/poster`) con limiti giornalieri; l'app non contiene più la chiave del Toolkit. **In attesa**: impostare `TOOLKIT_SECRET_KEY` e `TOOLKIT_URL` (server-only) nelle env del progetto — finché mancano, gli endpoint rispondono 503 e le 2 funzioni AI mostrano l'errore generico. Poi test end-to-end ed eliminazione di `EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY` / `EXPO_PUBLIC_TOOLKIT_URL`.
- In corso: marketing (Reddit, Google Ads, Apple Search Ads, social).

## Decisioni (data — decisione — motivo)
- 2026 — Prezzo Premium €1/mese e €6/anno — prezzo basso per convertire di più.
- 2026 — Avviso aggiornamento remoto via Supabase — cambiare messaggio senza nuova build né revisione.
- 07/11/2026 — Chiamate AI solo via Worker con quota per dispositivo e per IP (mood 30/giorno, poster 10/giorno; tetto globale 5000/1000, costanti in `functions/ai-usage.ts`) — la chiave nel binario era estraibile e usabile da chiunque. IP salvato solo come hash SHA-256 con sale giornaliero casuale.
- 2026 — Prima di aggiungere contenuti (es. quiz), verificare quelli esistenti — evitare doppioni.

## Changelog
- 07/11/2026 — Proxy AI: nuovi `functions/ai.ts` (validazione, prompt e modelli lato server) e `functions/ai-usage.ts` (Durable Object contatori); rotte in `functions/index.ts`. iOS: `MoodTextAnalyzer` e `PosterScanService` chiamano il Worker senza chiave; 429 → messaggio `ai.limit.*` (6 lingue, `scripts/add_ai_limit_strings.py`).
- 07/11/2026 — `CloudSyncService.pushAllRows`: rimosso `deleteMissing` per `diary_check_ins` (upsert-only; le altre tabelle invariato) — evitate cancellazioni incrociate multi-dispositivo e query troppo lunghe.
- 05/11/2026 — Creati `PROJECT.md` e `SOCIAL.md` (memoria del progetto per le IA).
