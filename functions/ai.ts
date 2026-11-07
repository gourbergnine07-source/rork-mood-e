import type { AIKind } from "./ai-usage";

/**
 * Server-side AI proxy for the iOS app (POST /ai/mood, POST /ai/poster).
 *
 * The Rork Toolkit secret lives only here (env.TOOLKIT_SECRET_KEY); the
 * app sends just its anonymous deviceId plus the text or the JPEG. Model,
 * sampling parameters and system prompts are fixed server-side.
 * The response keeps the OpenAI-style shape the app already parses:
 * { choices: [ { message: { content } } ] }.
 *
 * Privacy: the user's text and image are forwarded to the model for this
 * single call and are never logged or stored.
 */

export type AIEnv = {
  DO: Fetcher;
  TOOLKIT_SECRET_KEY?: string;
  TOOLKIT_URL?: string;
};

const MAX_DEVICE_ID = 64;
const MAX_MOOD_TEXT = 500;
/** ~3.5 MB: client JPEG budget is 2.5 MB before base64 (~3.34 MB after). */
const MAX_POSTER_BODY_BYTES = 3_600_000;
const MOOD_TIMEOUT_MS = 25_000;
const POSTER_TIMEOUT_MS = 45_000;

// Mirrors the iOS Mood / ViewingGoal enum raw values (same order).
const MOODS = [
  "felice", "triste", "stressato", "annoiato", "innamorato", "nostalgico",
  "arrabbiato", "motivato", "malinconico", "spensierato", "curioso", "impaurito",
];
const GOALS = [
  "ridere", "piangere", "rilassarmi", "riflettere", "emozionarmi",
  "distrarmi", "ispirarmi", "paura", "sognare", "innamorarmi",
];

const MOOD_SYSTEM_PROMPT = `You classify how a person feels based on a short free-form text (any language) about their day or mood, to recommend a movie.

Pick exactly one mood id from this list: ${MOODS.join(", ")}.
If the text also implies what they want from the movie tonight, pick one goal id from this list: ${GOALS.join(", ")}. Otherwise use null.

Reply with ONLY a minified JSON object, no markdown, no explanation:
{"mood":"<mood id>","goal":"<goal id or null>"}`;

const POSTER_PROMPT = `You identify posters of movies and TV series. The photo may be blurry, tilted, partially cropped, taken at an angle, or a photo of a screen/monitor — do your best anyway using the artwork, typography, actors and any readable text.
Reply ONLY with minified JSON, no markdown, in this exact shape:
{"candidates":[{"title":"<title>","year":<first release year or null>,"type":"movie|tv","confidence":"high|medium|low"}]}
Rules:
- "type" MUST be "tv" when the poster is for a TV/streaming series (Netflix, Apple TV+, HBO, etc.), "movie" for feature films. Many series posters look like movie posters — check carefully.
- Return 1 candidate with confidence "high" ONLY if you are absolutely certain; otherwise ALWAYS return 2-3 plausible candidates ordered from most to least likely.
- Use the original or best-known international title so it can be found on TMDB.
- If the image is clearly not a movie or TV series poster, reply {"candidates":[]}.`;

function json(body: unknown, status: number, cors: Record<string, string>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

function validDeviceId(value: unknown): value is string {
  return typeof value === "string" && value.length > 0 && value.length <= MAX_DEVICE_ID;
}

/** True when the base64 payload decodes to bytes starting with FF D8 (JPEG SOI). */
function looksLikeJPEG(base64: string): boolean {
  try {
    const head = atob(base64.slice(0, 8));
    return head.charCodeAt(0) === 0xff && head.charCodeAt(1) === 0xd8;
  } catch {
    return false;
  }
}

/** Atomically checks and consumes one unit of the daily quota. */
async function consumeQuota(
  env: AIEnv,
  kind: AIKind,
  deviceId: string,
  ip: string,
): Promise<"ok" | "limit" | "unavailable"> {
  const request = new Request("https://internal/consume", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Rork-DO-Class": "AIUsageCounter",
      "X-Rork-DO-Id": "global",
    },
    body: JSON.stringify({ kind, deviceId, ip }),
  });
  const response = await env.DO.fetch(request);
  if (response.status === 429) return "limit";
  if (!response.ok) return "unavailable";
  return "ok";
}

/** Calls the toolkit chat endpoint and reshapes the reply to choices[0].message.content. */
async function callModel(
  env: AIEnv,
  payload: Record<string, unknown>,
  timeoutMs: number,
  kind: AIKind,
  cors: Record<string, string>,
): Promise<Response> {
  let upstream: Response;
  try {
    upstream = await fetch(`${env.TOOLKIT_URL}/v2/vercel/v1/chat/completions`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${env.TOOLKIT_SECRET_KEY}`,
      },
      body: JSON.stringify(payload),
      signal: AbortSignal.timeout(timeoutMs),
    });
  } catch (error) {
    const timedOut = error instanceof Error && error.name === "TimeoutError";
    console.warn(`ai/${kind}: upstream ${timedOut ? "timeout" : "fetch failed"}`);
    return json({ error: timedOut ? "timeout" : "upstream" }, timedOut ? 504 : 502, cors);
  }

  if (!upstream.ok) {
    // Status only: the upstream body may echo the user's input.
    console.warn(`ai/${kind}: upstream HTTP ${upstream.status}`);
    return json({ error: "upstream" }, 502, cors);
  }

  try {
    const data = (await upstream.json()) as {
      choices?: { message?: { content?: string | null } }[];
    };
    const content = data.choices?.[0]?.message?.content ?? null;
    return json({ choices: [{ message: { content } }] }, 200, cors);
  } catch {
    console.warn(`ai/${kind}: upstream returned invalid JSON`);
    return json({ error: "upstream" }, 502, cors);
  }
}

export async function handleAI(
  request: Request,
  env: AIEnv,
  kind: AIKind,
  cors: Record<string, string>,
): Promise<Response> {
  if (request.method !== "POST") {
    return json({ error: "method" }, 405, cors);
  }
  if (!env.TOOLKIT_SECRET_KEY || !env.TOOLKIT_URL) {
    console.error("ai: TOOLKIT_SECRET_KEY / TOOLKIT_URL not configured");
    return json({ error: "unavailable" }, 503, cors);
  }

  // Size guard before reading the body (poster) — mood bodies are tiny.
  const maxBytes = kind === "poster" ? MAX_POSTER_BODY_BYTES : 16_000;
  const declared = Number(request.headers.get("Content-Length") ?? "0");
  if (declared > maxBytes) {
    return json({ error: "too_large" }, 413, cors);
  }
  const raw = await request.text();
  if (raw.length > maxBytes) {
    return json({ error: "too_large" }, 413, cors);
  }

  let body: Record<string, unknown>;
  try {
    body = JSON.parse(raw) as Record<string, unknown>;
  } catch {
    return json({ error: "invalid" }, 400, cors);
  }

  const deviceId = body.deviceId;
  if (!validDeviceId(deviceId)) {
    return json({ error: "invalid" }, 400, cors);
  }

  let payload: Record<string, unknown>;
  let timeoutMs: number;

  if (kind === "mood") {
    const text = typeof body.text === "string" ? body.text.trim() : "";
    // Counted in Unicode code points (the app truncates the same way).
    const length = Array.from(text).length;
    if (length < 1 || length > MAX_MOOD_TEXT) {
      return json({ error: "invalid" }, 400, cors);
    }
    payload = {
      model: "google/gemini-3.1-flash-lite",
      temperature: 0,
      max_tokens: 2000,
      messages: [
        { role: "system", content: MOOD_SYSTEM_PROMPT },
        { role: "user", content: text },
      ],
    };
    timeoutMs = MOOD_TIMEOUT_MS;
  } else {
    const image = typeof body.image === "string" ? body.image : "";
    if (!image || !looksLikeJPEG(image)) {
      return json({ error: "invalid" }, 400, cors);
    }
    payload = {
      model: "google/gemini-3-flash",
      temperature: 0,
      max_tokens: 2000,
      reasoning_effort: "low",
      messages: [
        {
          role: "user",
          content: [
            { type: "text", text: POSTER_PROMPT },
            { type: "image_url", image_url: { url: `data:image/jpeg;base64,${image}` } },
          ],
        },
      ],
    };
    timeoutMs = POSTER_TIMEOUT_MS;
  }

  // Quota is consumed only for valid requests, right before the model call.
  const ip = request.headers.get("CF-Connecting-IP") ?? "";
  const quota = await consumeQuota(env, kind, deviceId, ip);
  if (quota === "limit") return json({ error: "limit" }, 429, cors);
  if (quota === "unavailable") return json({ error: "unavailable" }, 503, cors);

  return callModel(env, payload, timeoutMs, kind, cors);
}
