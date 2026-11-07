import { DurableObject } from "cloudflare:workers";

/**
 * Daily (UTC) usage counters for the AI proxy endpoints (/ai/mood,
 * /ai/poster). One global instance, same dispatch pattern as AdviceBoard
 * and MoodStatusBoard.
 *
 * Privacy: the caller's IP arrives in the request body only to be hashed
 * here (SHA-256 of IP + a random salt that changes every UTC day). The raw
 * IP is never stored or logged; yesterday's salts and counters are purged,
 * so hashes cannot be linked across days.
 */

export type AIKind = "mood" | "poster";

/** Per-device and per-IP daily limits. */
export const PER_USER_DAILY_LIMIT: Record<AIKind, number> = {
  mood: 30,
  poster: 10,
};

/** Global daily cap per endpoint (all users combined). Easy to change. */
export const GLOBAL_DAILY_CAP: Record<AIKind, number> = {
  mood: 5000,
  poster: 1000,
};

type ConsumeBody = { kind: AIKind; deviceId: string; ip: string };

function utcDay(): string {
  return new Date().toISOString().slice(0, 10);
}

function randomHex(bytes: number): string {
  const buf = new Uint8Array(bytes);
  crypto.getRandomValues(buf);
  return Array.from(buf, (b) => b.toString(16).padStart(2, "0")).join("");
}

async function sha256Hex(input: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(input));
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, "0")).join("");
}

type Env = Record<string, unknown>;

export class AIUsageCounter extends DurableObject<Env> {
  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    this.ctx.storage.sql.exec(`
      CREATE TABLE IF NOT EXISTS salts (
        day TEXT PRIMARY KEY,
        salt TEXT NOT NULL
      );
      CREATE TABLE IF NOT EXISTS counters (
        day TEXT NOT NULL,
        key TEXT NOT NULL,
        count INTEGER NOT NULL,
        PRIMARY KEY (day, key)
      );
    `);
  }

  /** Returns today's salt, creating it (and purging older days) on first use. */
  private saltFor(day: string): string {
    const row = this.ctx.storage.sql
      .exec<{ salt: string }>("SELECT salt FROM salts WHERE day = ?", day)
      .toArray()[0];
    if (row) return row.salt;
    const salt = randomHex(32);
    this.ctx.storage.sql.exec("INSERT INTO salts (day, salt) VALUES (?, ?)", day, salt);
    this.ctx.storage.sql.exec("DELETE FROM salts WHERE day < ?", day);
    this.ctx.storage.sql.exec("DELETE FROM counters WHERE day < ?", day);
    return salt;
  }

  private count(day: string, key: string): number {
    const row = this.ctx.storage.sql
      .exec<{ count: number }>("SELECT count FROM counters WHERE day = ? AND key = ?", day, key)
      .toArray()[0];
    return row?.count ?? 0;
  }

  private increment(day: string, key: string): void {
    this.ctx.storage.sql.exec(
      `INSERT INTO counters (day, key, count) VALUES (?, ?, 1)
       ON CONFLICT(day, key) DO UPDATE SET count = count + 1`,
      day,
      key,
    );
  }

  override async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    if (request.method !== "POST" || url.pathname !== "/consume") {
      return new Response("not found", { status: 404 });
    }

    let body: ConsumeBody;
    try {
      body = (await request.json()) as ConsumeBody;
    } catch {
      return Response.json({ error: "invalid" }, { status: 400 });
    }
    const { kind, deviceId, ip } = body;
    if ((kind !== "mood" && kind !== "poster") || typeof deviceId !== "string") {
      return Response.json({ error: "invalid" }, { status: 400 });
    }

    const day = utcDay();
    // Hash before touching storage: only the salted hash is ever persisted.
    const ipHash = await sha256Hex(`${ip || "unknown"}|${this.saltFor(day)}`);

    // No await between the reads and the writes below: the check-and-
    // increment runs atomically inside this single-threaded object.
    const globalKey = `${kind}:global`;
    const deviceKey = `${kind}:dev:${deviceId}`;
    const ipKey = `${kind}:ip:${ipHash}`;

    if (this.count(day, globalKey) >= GLOBAL_DAILY_CAP[kind]) {
      return Response.json({ error: "unavailable" }, { status: 503 });
    }
    const limit = PER_USER_DAILY_LIMIT[kind];
    if (this.count(day, deviceKey) >= limit || this.count(day, ipKey) >= limit) {
      return Response.json({ error: "limit" }, { status: 429 });
    }

    this.increment(day, globalKey);
    this.increment(day, deviceKey);
    this.increment(day, ipKey);
    return Response.json({ ok: true });
  }
}
