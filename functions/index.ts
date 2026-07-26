export { AdviceBoard } from "./advice-board";
import { inviteHtml } from "./invite-page";

type Env = { DO: Fetcher };

const CORS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

/**
 * Edge cache for hot, device-agnostic community reads.
 *
 * The board list and the weekly stats are identical for every user
 * (ownership badges are overlaid on-device from locally stored ids),
 * so they can be served from a shared cache instead of hitting the
 * Durable Object on every request. Two layers:
 *  1. per-isolate memory cache (fastest, survives across requests
 *     handled by the same worker isolate)
 *  2. Cloudflare edge cache (shared per data center)
 * Writes always pass through; personalized reads (detail, profile,
 * activity) are never cached.
 */
const LIST_TTL_SECONDS = 30;
const STATS_TTL_SECONDS = 300;

type MemoryEntry = { expiresAt: number; body: string };
const memoryCache = new Map<string, MemoryEntry>();

/** Returns the cache TTL for a cacheable read, or null for pass-through. */
function cacheTTLSeconds(method: string, path: string): number | null {
  if (method !== "GET") return null;
  if (path === "/advice/stats") return STATS_TTL_SECONDS;
  if (path === "/advice/requests") return LIST_TTL_SECONDS;
  return null;
}

/** Canonical cache key: drops deviceId and any unknown params. */
function canonicalAdviceURL(url: URL): string {
  const params = new URLSearchParams();
  const mood = url.searchParams.get("mood");
  const limit = url.searchParams.get("limit");
  if (mood) params.set("mood", mood);
  if (limit) params.set("limit", limit);
  const query = params.toString();
  return `${url.origin}${url.pathname}${query ? `?${query}` : ""}`;
}

function jsonResponse(body: string, ttl: number, cacheState: string): Response {
  return new Response(body, {
    headers: {
      ...CORS,
      "Content-Type": "application/json",
      "Cache-Control": `public, max-age=${ttl}`,
      "X-Cache": cacheState,
    },
  });
}

/** Routes a request to the single global AdviceBoard Durable Object. */
function fetchFromBoard(env: Env, targetURL: string, original?: Request): Promise<Response> {
  const wrapped = original ? new Request(targetURL, original) : new Request(targetURL);
  wrapped.headers.set("X-Rork-DO-Class", "AdviceBoard");
  wrapped.headers.set("X-Rork-DO-Id", "global");
  return env.DO.fetch(wrapped);
}

function pruneMemoryCache(now: number): void {
  if (memoryCache.size <= 64) return;
  for (const [key, entry] of memoryCache) {
    if (entry.expiresAt <= now) memoryCache.delete(key);
  }
}

/**
 * Serves a shared community read from cache, falling back to the
 * Durable Object on miss. Errors are never cached.
 */
async function cachedAdviceRead(
  env: Env,
  ctx: ExecutionContext,
  url: URL,
  ttl: number,
): Promise<Response> {
  const canonical = canonicalAdviceURL(url);
  const now = Date.now();

  const hot = memoryCache.get(canonical);
  if (hot && hot.expiresAt > now) {
    return jsonResponse(hot.body, ttl, "HIT-MEMORY");
  }

  const cacheKey = new Request(canonical, { method: "GET" });
  const edge = await caches.default.match(cacheKey).catch(() => undefined);
  if (edge) {
    const body = await edge.text();
    memoryCache.set(canonical, { expiresAt: now + ttl * 1000, body });
    return jsonResponse(body, ttl, "HIT-EDGE");
  }

  const origin = await fetchFromBoard(env, canonical);
  if (!origin.ok) {
    const failed = new Response(origin.body, origin);
    for (const [key, value] of Object.entries(CORS)) {
      failed.headers.set(key, value);
    }
    return failed;
  }

  const body = await origin.text();
  memoryCache.set(canonical, { expiresAt: now + ttl * 1000, body });
  pruneMemoryCache(now);
  ctx.waitUntil(
    caches.default
      .put(
        cacheKey,
        new Response(body, {
          headers: {
            "Content-Type": "application/json",
            "Cache-Control": `public, max-age=${ttl}`,
          },
        }),
      )
      .catch(() => {
        // Cache API can be unavailable in some environments; safe to skip.
      }),
  );
  return jsonResponse(body, ttl, "MISS");
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS });
    }

    if (url.pathname === "/ping") {
      return Response.json({ ok: true, now: new Date().toISOString() });
    }

    if (url.pathname === "/invite") {
      // Friend-invite landing page shared from the iOS app.
      const rawCode = url.searchParams.get("code") ?? "";
      const code = rawCode.toUpperCase().replace(/[^A-Z0-9]/g, "").slice(0, 12);
      const lang = (url.searchParams.get("l") ?? "en").toLowerCase().slice(0, 2);
      return new Response(inviteHtml(code, lang), {
        headers: { "Content-Type": "text/html; charset=utf-8" },
      });
    }

    if (url.pathname.startsWith("/advice")) {
      // Hot shared reads (board list, weekly stats) go through the edge cache.
      const ttl = cacheTTLSeconds(request.method, url.pathname);
      if (ttl !== null) {
        return cachedAdviceRead(env, ctx, url, ttl);
      }

      // Everything else (writes, detail, profile, activity) hits the board directly.
      const response = await fetchFromBoard(env, request.url, request);
      const withCors = new Response(response.body, response);
      for (const [key, value] of Object.entries(CORS)) {
        withCors.headers.set(key, value);
      }
      return withCors;
    }

    return new Response("not found", { status: 404 });
  },
} satisfies ExportedHandler<Env>;
