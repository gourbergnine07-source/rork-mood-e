/**
 * Localized HTML landing page for friend invites.
 * Opened from shared invite links: shows the friend code, a deep link
 * into the app and the App Store download button.
 */

const APP_STORE_URL = "https://apps.apple.com/app/id6792271949";

type InviteStrings = {
  title: string;
  subtitle: string;
  codeLabel: string;
  open: string;
  download: string;
  note: string;
};

const STRINGS: Record<string, InviteStrings> = {
  en: {
    title: "You've been invited to Mood-E! 🎬",
    subtitle:
      "Movies that match your mood. Download the app and add this friend code to compare your cinema stats.",
    codeLabel: "Friend code",
    open: "Open Mood-E",
    download: "Download on the App Store",
    note: "Already have the app? Tap “Open Mood-E” to add your friend.",
  },
  it: {
    title: "Sei stato invitato su Mood-E! 🎬",
    subtitle:
      "Film su misura per il tuo umore. Scarica l'app e aggiungi questo codice amico per confrontare le vostre statistiche da cinefili.",
    codeLabel: "Codice amico",
    open: "Apri Mood-E",
    download: "Scarica dall'App Store",
    note: "Hai già l'app? Tocca “Apri Mood-E” per aggiungere il tuo amico.",
  },
  es: {
    title: "¡Te han invitado a Mood-E! 🎬",
    subtitle:
      "Películas a la medida de tu estado de ánimo. Descarga la app y añade este código de amigo para comparar vuestras estadísticas de cine.",
    codeLabel: "Código de amigo",
    open: "Abrir Mood-E",
    download: "Descargar en el App Store",
    note: "¿Ya tienes la app? Toca “Abrir Mood-E” para añadir a tu amigo.",
  },
  fr: {
    title: "Tu es invité sur Mood-E ! 🎬",
    subtitle:
      "Des films selon ton humeur. Télécharge l'app et ajoute ce code ami pour comparer vos statistiques de cinéphiles.",
    codeLabel: "Code ami",
    open: "Ouvrir Mood-E",
    download: "Télécharger sur l'App Store",
    note: "Tu as déjà l'app ? Touche « Ouvrir Mood-E » pour ajouter ton ami.",
  },
};

/**
 * Renders the invite landing page. `code` must already be sanitized to
 * uppercase alphanumerics by the caller.
 */
export function inviteHtml(code: string, lang: string): string {
  const t = STRINGS[lang] ?? STRINGS.en;
  const displayCode = code.length > 0 ? code : "······";
  const deepLink = `moode://invite/${code}`;

  return `<!doctype html>
<html lang="${lang}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Mood-E</title>
<meta property="og:title" content="${t.title}">
<meta property="og:description" content="${t.subtitle}">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    background: radial-gradient(120% 90% at 50% 0%, #221a33 0%, #120e1c 55%, #0b0912 100%);
    color: #f4f1fa;
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 24px;
  }
  .card {
    width: 100%;
    max-width: 420px;
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.10);
    border-radius: 28px;
    padding: 36px 28px;
    text-align: center;
    backdrop-filter: blur(12px);
  }
  .emoji { font-size: 56px; }
  h1 { font-size: 22px; font-weight: 800; margin: 14px 0 10px; }
  p.sub { font-size: 15px; line-height: 1.5; color: #beb6d2; }
  .code-box {
    margin: 24px 0;
    padding: 16px;
    background: rgba(255, 179, 71, 0.10);
    border: 1px dashed rgba(255, 179, 71, 0.45);
    border-radius: 18px;
  }
  .code-label {
    font-size: 12px;
    font-weight: 700;
    letter-spacing: 1px;
    text-transform: uppercase;
    color: #ffb347;
  }
  .code {
    font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
    font-size: 32px;
    font-weight: 900;
    letter-spacing: 4px;
    color: #ffd28a;
    margin-top: 6px;
  }
  a.btn {
    display: block;
    padding: 15px;
    border-radius: 15px;
    font-size: 16px;
    font-weight: 700;
    text-decoration: none;
    margin-top: 12px;
  }
  a.primary { background: #e8564f; color: #fff; }
  a.secondary {
    background: rgba(255, 255, 255, 0.08);
    color: #f4f1fa;
    border: 1px solid rgba(255, 255, 255, 0.14);
  }
  p.note { font-size: 12.5px; color: #8f87a6; margin-top: 18px; line-height: 1.5; }
</style>
</head>
<body>
  <main class="card">
    <div class="emoji">🍿</div>
    <h1>${t.title}</h1>
    <p class="sub">${t.subtitle}</p>
    <div class="code-box">
      <div class="code-label">${t.codeLabel}</div>
      <div class="code">${displayCode}</div>
    </div>
    <a class="btn primary" href="${APP_STORE_URL}">${t.download}</a>
    <a class="btn secondary" href="${deepLink}">${t.open}</a>
    <p class="note">${t.note}</p>
  </main>
</body>
</html>`;
}
