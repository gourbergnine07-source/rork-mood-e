# Config remota versione app (`app_release_config`)

Sistema di avviso aggiornamenti: l'app legge questa tabella Supabase ad ogni avvio
(e ritorno in foreground) e decide se mostrare il banner "nuova versione" o la
schermata bloccante. **Aggiornare i valori qui non richiede mai una nuova build.**

| Colonna | Significato |
|---|---|
| `latest_version` | Ultima versione disponibile sull'App Store (es. `1.5`). Se l'installata è inferiore → banner discreto in Home, chiudibile, max 1 volta al giorno. |
| `minimum_required_version` | Versione minima per usare l'app (es. `1.0`). Se l'installata è inferiore → schermata bloccante. **Usare solo per rotture tecniche reali.** |
| `notes` | (opzionale) messaggio personalizzato per lingua: `{"it": "…", "en": "…"}`. Se assente, viene usato il testo localizzato standard. |

## Come aggiornare (nessuna build richiesta)

Aggiornare la riga `ios` via migrazione (o SQL editor) su Supabase:

```sql
UPDATE app_release_config
SET latest_version = '1.6',            -- nuova versione pubblicata
    minimum_required_version = '1.0',  -- alza solo per rotture tecniche
    notes = NULL,                      -- oppure {"it": "Novità: …"} per un messaggio custom
    updated_at = now()
WHERE platform = 'ios';
```

Per nascondere l'avviso (es. nessuno da aggiornare): impostare `latest_version`
pari alla versione attualmente in uso (es. `1.5`).

## Regole implementate nell'app (`AppUpdateService`)

- Lettura remota throttled (max ogni 4h), cache offline in `UserDefaults`.
- Il blocco (`minimum_required_version`) viene limitato a `latest_version`:
  mai bloccare utenti senza una versione installabile.
- Banner: al massimo una volta al giorno, sempre visibile appena pubblicate
  versioni più recenti dell'ultimo annuncio.
- Link diretto alla scheda App Store: `https://apps.apple.com/app/id6792271949`.
- Se il fetch fallisce, l'app funziona normalmente (fallback silenzioso).
