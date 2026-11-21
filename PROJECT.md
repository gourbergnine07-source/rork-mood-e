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
- 21/11/2026: le funzioni AI funzionano end-to-end (testato: `POST /ai/mood` → 200 con mood+goal). Il Worker usa `TOOLKIT_URL=toolkit.rork.com` e, come chiave, `TOOLKIT_SECRET_KEY` se valorizzata, altrimenti la chiave gestita da Rork (`EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY`, mai visibile né copiabile). La vecchia `TOOLKIT_SECRET_KEY` sbagliata (conteneva il nome letterale) è stata eliminata; non serve ruotare la chiave, le versioni già installate continuano a funzionare.
- Fix 21/11/2026: libreria e planner (`library_entries`, `planner_scheduled`, `planner_memories`) usano la cancellazione logica (`deleted_at`) invece di `deleteMissing`: un dispositivo non cancella più dal cloud ciò che non ha ancora visto. Le cancellazioni locali finiscono nella lista "suppressionsEnAttente" (UserDefaults, per tabella e utente) e vengono inviate alla sync successiva; righe con `deleted_at` più vecchio di 60 giorni eliminate una volta al giorno. Build ok, **test su due dispositivi ancora da fare**. Le versioni ≤1.6 già installate usano ancora `deleteMissing` finché non vengono aggiornate.
- Sicurezza 21/11/2026: `POST /status/friend/register` (amicizie Stato Mood via codici Duo/Sfida) limitato a 10/ora per deviceId e 15/ora per IP (hash) → 429 `{"error":"limit"}`; l'app installata ignora l'errore (nessun crash, nessuna UI nuova). Campo opzionale `role` ("host"/"guest") attivo sul server; dal 21/11/2026 il codice iOS lo invia (host = chi crea, guest = chi entra), **ma solo dalla prossima build pubblicata**: le versioni ≤1.6 installate restano sul comportamento vecchio protetto solo dai limiti. Testato in produzione (vedi Changelog).
- Supabase (21/11/2026): `duo_sessions` e `challenge_duos` restano **leggibili** da `anon` per tutte le righe non scadute (si possono elencare i codici attivi): fix 1 (RPC `get_duo_session`/`join_duo_session` + revoca SELECT) rimandata alla build finale. UPDATE ora consentito solo sulle colonne usate dall'app (fix 2, applicata). `add_friend_by_code`: max 10 tentativi/ora per utente (fix 3, applicata); codice errato o proprio → nessuna riga (l'app mostra l'errore generico), oltre il limite → `RATE_LIMITED` (errore generico nell'app).
- Moderazione 21/11/2026: i titoli dei film (da TMDB) NON sono più filtrati né sul Worker né nell'app: titoli reali come "Moby Dick", "Porco Rosso", "Dick Tracy" passano. Il filtro resta su testo libero, nicknames e nomi condivisi. Tolte "porco"/"porca" dalle liste (parole italiane normali) in `functions/moderation.ts` e in `ios/MoodE/Utilities/ContentModeration.swift`. Limiti noti (segnalati, non corretti): la lista blocca solo parole intere al singolare (es. "puttane" plurale passa) e le due liste non sono perfettamente identiche: sul Worker c'è anche "merde" (fr), nell'app no.
- Limite noto: il backup iCloud (`ICloudSyncService`) non propaga le cancellazioni (fusione per unione): un elemento cancellato può tornare dal backup iCloud. Non modificato.
- In corso: marketing (Reddit, Google Ads, Apple Search Ads, social).

## Decisioni (data — decisione — motivo)
- 2026 — Prezzo Premium €1/mese e €6/anno — prezzo basso per convertire di più.
- 2026 — Avviso aggiornamento remoto via Supabase — cambiare messaggio senza nuova build né revisione.
- 07/11/2026 — Chiamate AI solo via Worker con quota per dispositivo e per IP (mood 30/giorno, poster 10/giorno; tetto globale 5000/1000, costanti in `functions/ai-usage.ts`) — la chiave nel binario era estraibile e usabile da chiunque. IP salvato solo come hash SHA-256 con sale giornaliero casuale.
- 21/11/2026 — Cancellazioni sync = soft delete (`deleted_at` impostato all'invio, a lotti di 100 con `.in()`), mai "cancella ciò che manca in locale"; pulizia definitiva dopo 60 giorni via filtro sulla data — i dispositivi si cancellavano a vicenda i dati non ancora sincronizzati. Gli upsert non inviano `deleted_at` (versioni vecchie non resuscitano righe). Libreria (id = film, riaggiungibile): una riga cancellata resta se ha attività (aggiunta/visione) successiva a `deleted_at`, e in quel caso `deleted_at` torna null.
- 21/11/2026 — Anti-indovinamento codici amici: limiti orari (finestre allineate all'ora, le richieste rifiutate non contano) con IP salvato solo come SHA-256(IP + sale giornaliero casuale), come per l'AI; il router passa l'IP Cloudflare nell'header `X-Mood-Client-IP` (sempre sovrascritto). Ruoli: host apre il codice (non può prendere un codice già di un altro dispositivo); guest si collega solo all'unico host aperto e consuma il codice; codice inesistente/usato/scaduto → stessa risposta `{"ok":true,"linked":0}`. Senza `role` comportamento vecchio (le versioni installate chiamano il Worker in produzione); l'host resta anche in `friend_codes` per accoppiarsi con guest di versioni vecchie, e un collegamento legacy consuma il codice host. Un guest con ruolo NON si collega a un host di versione vecchia (niente fallback, altrimenti la protezione si aggira).
- 21/11/2026 — `add_friend_by_code`: codice errato/proprio restituisce 0 righe invece di sollevare `CODE_NOT_FOUND`/`OWN_CODE` — un'eccezione annullerebbe anche la registrazione del tentativo, rendendo il limite inutile. Successo invariato. Scelta confermata dall'utente.
- 21/11/2026 — UPDATE `anon`/`authenticated` per colonna: `duo_sessions` (guest_joined, guest_name, host_mood, host_goal, guest_mood, guest_goal), `challenge_duos` (guest_joined, guest_name, host_progress, guest_progress) — colonne lette dal codice iOS; code/expires_at/created_at/month_key/host_name non più modificabili. Policy RLS e SELECT invariati.
- 2026 — Prima di aggiungere contenuti (es. quiz), verificare quelli esistenti — evitare doppioni.

## Changelog
- 21/11/2026 — Moderazione titoli: `functions/advice-board.ts` (risposte bacheca) e `functions/mood-status.ts` (stati) non filtrano più `movieTitle` con `isCleanText`; rimosse "porco"/"porca" da `functions/moderation.ts` e da `ios/MoodE/Utilities/ContentModeration.swift`. Test in produzione: "Moby Dick", "Porco Rosso", "Dick Tracy" e il testo "porca miseria, che bel film" passano (200); "che cazzo vediamo", "sei uno stronzo", "che puttana", "vaffanculo", "merda" e nickname offensivo bloccati (400). L'app iOS non filtrava mai i titoli (nessuna modifica necessaria lato client).- 21/11/2026 — Supabase: migrazione `backend/migrations/0002_duo_update_columns_friend_code_limit.sql` (GRANT UPDATE per colonna su `duo_sessions`/`challenge_duos`; tabella `friend_code_attempts` con RLS e nessun accesso diretto; `add_friend_by_code` con limite 10/ora e lock per utente). Test REST in produzione con chiave pubblica: insert/aggiornamenti dell'app → 201/204, modifica di `code`/`expires_at`/`month_key` → 401. `add_friend_by_code` con login non testato (serve un utente reale). Righe di test: codice `364140` (duo scade in 3h; challenge con `month_key` `test-sec`, invisibile agli utenti).
- 21/11/2026 — iOS: `StatusService.registerFriendCode(_:role:)` invia `"role"`; `DuoNightView` e `ChallengeDuoView`: crea → host, entra → guest. Nessuna modifica UI. Build simulatore ok, non testato su dispositivo.
- 21/11/2026 — Codici amici: `functions/index.ts` (header `X-Mood-Client-IP` solo per `/status/friend/register`); `functions/mood-status.ts` (tabelle `friend_code_hosts`, `friend_rate_salts`, `friend_rate_counters`; limiti 10/15 all'ora; ruoli host/guest; purge notturna di host >24h, contatori e sali vecchi). Test in produzione: pairing senza ruolo ok, host+guest ok, secondo guest e codice usato → `linked:0`, codice inesistente → `linked:0`, 11ª richiesta dallo stesso dispositivo → 429, 16ª dallo stesso IP → 429. iOS non modificato.
- 21/11/2026 — AI end-to-end: `functions/ai.ts` usa come chiave `TOOLKIT_SECRET_KEY` oppure la chiave gestita `EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY` (fallback); `TOOLKIT_URL=toolkit.rork.com`, eliminata la `TOOLKIT_SECRET_KEY` sbagliata. Testato `/ai/mood` → 200. `/ai/poster` da provare dall'app (stesso percorso auth).
- 21/11/2026 — Sync soft delete: migrazione `backend/migrations/0001_sync_soft_delete.sql` (colonna `deleted_at` + indici, dati invariati); nuovo `ios/MoodE/Services/PendingDeletions.swift`; `SupabaseService` (campo `deletedAt` nelle struct Remote*); `CloudSyncService` (pre-fusione che rispetta cancellazioni, soft delete/ripristino a lotti, purge giornaliera, rimosso `deleteMissing`, log `CloudSync:`); `MovieLibrary` e `MoviePlanner` registrano le cancellazioni.
- 07/11/2026 — Proxy AI: nuovi `functions/ai.ts` (validazione, prompt e modelli lato server) e `functions/ai-usage.ts` (Durable Object contatori); rotte in `functions/index.ts`. iOS: `MoodTextAnalyzer` e `PosterScanService` chiamano il Worker senza chiave; 429 → messaggio `ai.limit.*` (6 lingue, `scripts/add_ai_limit_strings.py`).
- 07/11/2026 — `CloudSyncService.pushAllRows`: rimosso `deleteMissing` per `diary_check_ins` (upsert-only; le altre tabelle invariato) — evitate cancellazioni incrociate multi-dispositivo e query troppo lunghe.
- 05/11/2026 — Creati `PROJECT.md` e `SOCIAL.md` (memoria del progetto per le IA).
