/**
 * Lightweight profanity filter shared by every community write path.
 * Matches whole words (accent-insensitive) in IT / EN / ES / FR.
 * The same list is mirrored client-side in the iOS app.
 */
const BLOCKED_WORDS: string[] = [
  // Italian
  "cazzo", "merda", "stronzo", "stronza", "vaffanculo", "puttana", "troia",
  "coglione", "bastardo", "porca", "porco", "negro", "frocio", "mignotta",
  "zoccola", "pompino", "culo",
  // English
  "fuck", "shit", "bitch", "asshole", "bastard", "cunt", "dick", "faggot",
  "nigger", "whore", "slut", "retard",
  // Spanish
  "mierda", "puta", "puto", "gilipollas", "cabron", "cabrón", "joder",
  "pendejo", "maricon", "maricón", "coño", "polla", "zorra",
  // French
  "merde", "putain", "salope", "connard", "connasse", "encule", "enculé",
  "pute", "batard", "bâtard", "nique", "pd",
];

const blockedSet = new Set(BLOCKED_WORDS.map((word) => normalize(word)));

function normalize(text: string): string {
  return text
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "");
}

/** True when the text contains no blocked word. */
export function isCleanText(text: string): boolean {
  const words = normalize(text).split(/[^a-z0-9]+/);
  return !words.some((word) => word.length > 1 && blockedSet.has(word));
}
