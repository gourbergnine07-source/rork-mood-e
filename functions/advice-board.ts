import { DurableObject } from "cloudflare:workers";
import { isCleanText } from "./moderation";

/**
 * Shared anonymous advice board for Mood-E.
 * One global instance stores advice requests, movie replies, helpful marks
 * and abuse reports. No personal data: users are identified only by a
 * random device id and a self-generated anonymous nickname.
 */

const VALID_MOODS = new Set([
  "felice", "triste", "stressato", "annoiato", "innamorato", "nostalgico",
  "arrabbiato", "motivato", "malinconico", "spensierato", "curioso", "impaurito",
]);

const MAX_TEXT = 200;
const MAX_NICKNAME = 30;
const REPORT_HIDE_THRESHOLD = 3;
const MAX_REQUESTS_PER_DAY = 10;
const MAX_REPLIES_PER_DAY = 40;

/** Hidden (reported) content is retained this long before being purged for good. */
const HIDDEN_RETENTION_MS = 30 * 24 * 60 * 60 * 1000;
/** Hour of day (UTC) at which the nightly maintenance alarm fires. */
const MAINTENANCE_HOUR_UTC = 4;

type Env = {
  DO: Fetcher & {
    setAlarm(className: string, id: string, scheduledTime: number | Date): Promise<void>;
    getAlarm(className: string, id: string): Promise<number | null>;
    deleteAlarm(className: string, id: string): Promise<void>;
  };
};

type RequestRow = {
  id: string;
  device_id: string;
  nickname: string;
  mood: string;
  text: string;
  created_at: number;
  reply_count: number;
};

type ReplyRow = {
  id: string;
  request_id: string;
  device_id: string;
  nickname: string;
  movie_id: number;
  movie_title: string;
  poster_path: string | null;
  text: string | null;
  created_at: number;
  helpful_count: number;
};

function bad(message: string, code = "invalid", status = 400): Response {
  return Response.json({ error: message, code }, { status });
}

/** Next occurrence of the nightly maintenance hour (UTC). */
function nextMaintenanceTime(): number {
  const next = new Date();
  next.setUTCHours(MAINTENANCE_HOUR_UTC, 0, 0, 0);
  if (next.getTime() <= Date.now()) {
    next.setUTCDate(next.getUTCDate() + 1);
  }
  return next.getTime();
}

export class AdviceBoard extends DurableObject<Env> {
  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    this.ctx.storage.sql.exec(`
      CREATE TABLE IF NOT EXISTS requests (
        id TEXT PRIMARY KEY,
        device_id TEXT NOT NULL,
        nickname TEXT NOT NULL,
        mood TEXT NOT NULL,
        text TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        hidden INTEGER NOT NULL DEFAULT 0
      );
      CREATE TABLE IF NOT EXISTS replies (
        id TEXT PRIMARY KEY,
        request_id TEXT NOT NULL,
        device_id TEXT NOT NULL,
        nickname TEXT NOT NULL,
        movie_id INTEGER NOT NULL,
        movie_title TEXT NOT NULL,
        poster_path TEXT,
        text TEXT,
        created_at INTEGER NOT NULL,
        hidden INTEGER NOT NULL DEFAULT 0
      );
      CREATE TABLE IF NOT EXISTS helpful (
        reply_id TEXT NOT NULL,
        device_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (reply_id, device_id)
      );
      CREATE TABLE IF NOT EXISTS reports (
        target_type TEXT NOT NULL,
        target_id TEXT NOT NULL,
        device_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (target_type, target_id, device_id)
      );
    `);
  }

  override async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;
    const method = request.method;

    try {
      if (method === "GET" && path === "/advice/requests") {
        return this.listRequests(url);
      }
      if (method === "POST" && path === "/advice/requests") {
        return this.createRequest(await request.json());
      }
      const detailMatch = path.match(/^\/advice\/requests\/([a-zA-Z0-9-]+)$/);
      if (method === "GET" && detailMatch) {
        return this.requestDetail(detailMatch[1], url);
      }
      if (method === "POST" && path === "/advice/replies") {
        return this.createReply(await request.json());
      }
      if (method === "POST" && path === "/advice/helpful") {
        return this.markHelpful(await request.json());
      }
      if (method === "GET" && path === "/advice/profile") {
        return this.profile(url);
      }
      if (method === "POST" && path === "/advice/report") {
        return this.report(await request.json());
      }
      if (method === "GET" && path === "/advice/activity") {
        return this.activity(url);
      }
      if (method === "GET" && path === "/advice/stats") {
        return this.stats();
      }
      return new Response("not found", { status: 404 });
    } catch (error) {
      console.error("AdviceBoard error", path, error);
      return bad("internal error", "internal", 500);
    } finally {
      // Make sure the nightly maintenance alarm is always armed,
      // without blocking the response.
      this.ctx.waitUntil(this.ensureMaintenanceAlarm());
    }
  }

  // MARK: Scheduled maintenance

  /** Arms the nightly maintenance alarm if none is pending. */
  private async ensureMaintenanceAlarm(): Promise<void> {
    try {
      const pending = await this.env.DO.getAlarm("AdviceBoard", this.ctx.id.name ?? "global");
      if (pending === null) {
        const when = nextMaintenanceTime();
        await this.env.DO.setAlarm("AdviceBoard", this.ctx.id.name ?? "global", when);
        console.log("AdviceBoard maintenance alarm armed for", new Date(when).toISOString());
      }
    } catch (error) {
      console.warn("ensureMaintenanceAlarm failed", error);
    }
  }

  /**
   * Nightly background task (fires even with zero traffic, survives redeploys).
   * Idempotent: alarms are delivered at-least-once.
   * - Permanently purges reported/hidden content after 30 days.
   * - Removes orphaned helpful marks and reports.
   * Re-arms itself for the next night.
   */
  async onAlarm(info: { scheduledTime: number; retryCount: number; isRetry: boolean }): Promise<void> {
    if (info.isRetry) console.warn(`AdviceBoard maintenance retry #${info.retryCount}`);

    try {
      const cutoff = Date.now() - HIDDEN_RETENTION_MS;
      const sql = this.ctx.storage.sql;

      // Purge replies attached to old hidden requests, then the requests themselves.
      sql.exec(
        `DELETE FROM replies WHERE request_id IN
         (SELECT id FROM requests WHERE hidden = 1 AND created_at < ?)`,
        cutoff,
      );
      sql.exec("DELETE FROM requests WHERE hidden = 1 AND created_at < ?", cutoff);
      sql.exec("DELETE FROM replies WHERE hidden = 1 AND created_at < ?", cutoff);

      // Drop helpful marks and reports whose target no longer exists.
      sql.exec("DELETE FROM helpful WHERE reply_id NOT IN (SELECT id FROM replies)");
      sql.exec(
        `DELETE FROM reports WHERE
         (target_type = 'request' AND target_id NOT IN (SELECT id FROM requests)) OR
         (target_type = 'reply' AND target_id NOT IN (SELECT id FROM replies))`,
      );

      const requests = sql.exec<{ n: number }>("SELECT COUNT(*) AS n FROM requests").one().n;
      const replies = sql.exec<{ n: number }>("SELECT COUNT(*) AS n FROM replies").one().n;
      console.log(`AdviceBoard maintenance done: ${requests} requests, ${replies} replies remaining`);
    } finally {
      // Always re-arm for the next night, even if cleanup threw (retries aside).
      await this.env.DO.setAlarm("AdviceBoard", this.ctx.id.name ?? "global", nextMaintenanceTime());
    }
  }

  // MARK: Requests

  private listRequests(url: URL): Response {
    const mood = url.searchParams.get("mood");
    const deviceId = url.searchParams.get("deviceId") ?? "";
    const limit = Math.min(Number(url.searchParams.get("limit") ?? 50), 100);

    const rows = mood
      ? this.ctx.storage.sql.exec<RequestRow>(
          `SELECT r.*, (SELECT COUNT(*) FROM replies p WHERE p.request_id = r.id AND p.hidden = 0) AS reply_count
           FROM requests r WHERE r.hidden = 0 AND r.mood = ?
           ORDER BY r.created_at DESC LIMIT ?`,
          mood, limit,
        ).toArray()
      : this.ctx.storage.sql.exec<RequestRow>(
          `SELECT r.*, (SELECT COUNT(*) FROM replies p WHERE p.request_id = r.id AND p.hidden = 0) AS reply_count
           FROM requests r WHERE r.hidden = 0
           ORDER BY r.created_at DESC LIMIT ?`,
          limit,
        ).toArray();

    return Response.json({ requests: rows.map((row) => this.requestJSON(row, deviceId)) });
  }

  private createRequest(body: unknown): Response {
    const { deviceId, nickname, mood, text } = (body ?? {}) as Record<string, string>;
    if (!deviceId || !nickname || !mood || !text) return bad("missing fields");
    if (!VALID_MOODS.has(mood)) return bad("unknown mood");
    const trimmed = text.trim();
    if (trimmed.length === 0 || trimmed.length > MAX_TEXT) return bad("text length");
    if (nickname.length > MAX_NICKNAME) return bad("nickname too long");
    if (!isCleanText(trimmed) || !isCleanText(nickname)) {
      return bad("offensive content", "offensive");
    }

    const dayAgo = Date.now() - 24 * 60 * 60 * 1000;
    const count = this.ctx.storage.sql
      .exec<{ n: number }>("SELECT COUNT(*) AS n FROM requests WHERE device_id = ? AND created_at > ?", deviceId, dayAgo)
      .one().n;
    if (count >= MAX_REQUESTS_PER_DAY) return bad("daily limit reached", "rate_limited", 429);

    const id = crypto.randomUUID();
    const now = Date.now();
    this.ctx.storage.sql.exec(
      "INSERT INTO requests (id, device_id, nickname, mood, text, created_at) VALUES (?, ?, ?, ?, ?, ?)",
      id, deviceId, nickname, mood, trimmed, now,
    );

    return Response.json({
      request: {
        id, nickname, mood, text: trimmed, createdAt: now, replyCount: 0, isMine: true,
      },
    });
  }

  private requestDetail(id: string, url: URL): Response {
    const deviceId = url.searchParams.get("deviceId") ?? "";
    const rows = this.ctx.storage.sql.exec<RequestRow>(
      `SELECT r.*, (SELECT COUNT(*) FROM replies p WHERE p.request_id = r.id AND p.hidden = 0) AS reply_count
       FROM requests r WHERE r.id = ? AND r.hidden = 0`,
      id,
    ).toArray();
    if (rows.length === 0) return bad("not found", "not_found", 404);
    const requestRow = rows[0];

    const replies = this.ctx.storage.sql.exec<ReplyRow>(
      `SELECT p.*, (SELECT COUNT(*) FROM helpful h WHERE h.reply_id = p.id) AS helpful_count
       FROM replies p WHERE p.request_id = ? AND p.hidden = 0
       ORDER BY helpful_count DESC, p.created_at ASC`,
      id,
    ).toArray();

    const markedIds = new Set(
      this.ctx.storage.sql
        .exec<{ reply_id: string }>("SELECT reply_id FROM helpful WHERE device_id = ?", deviceId)
        .toArray()
        .map((row) => row.reply_id),
    );

    return Response.json({
      request: this.requestJSON(requestRow, deviceId),
      replies: replies.map((row) => ({
        id: row.id,
        nickname: row.nickname,
        movieId: row.movie_id,
        movieTitle: row.movie_title,
        posterPath: row.poster_path,
        text: row.text,
        createdAt: row.created_at,
        helpfulCount: row.helpful_count,
        isMine: row.device_id === deviceId,
        markedHelpful: markedIds.has(row.id),
      })),
    });
  }

  // MARK: Replies

  private createReply(body: unknown): Response {
    const { deviceId, nickname, requestId, movieTitle } = (body ?? {}) as Record<string, string>;
    const movieId = Number((body as Record<string, unknown>)?.movieId ?? 0);
    const posterPath = ((body as Record<string, unknown>)?.posterPath as string | undefined) ?? null;
    const rawText = ((body as Record<string, unknown>)?.text as string | undefined) ?? "";

    if (!deviceId || !nickname || !requestId || !movieTitle || !movieId) return bad("missing fields");
    const trimmed = rawText.trim().slice(0, MAX_TEXT);
    if (!isCleanText(trimmed) || !isCleanText(nickname) || !isCleanText(movieTitle)) {
      return bad("offensive content", "offensive");
    }

    const target = this.ctx.storage.sql
      .exec<{ device_id: string }>("SELECT device_id FROM requests WHERE id = ? AND hidden = 0", requestId)
      .toArray();
    if (target.length === 0) return bad("not found", "not_found", 404);

    const dayAgo = Date.now() - 24 * 60 * 60 * 1000;
    const count = this.ctx.storage.sql
      .exec<{ n: number }>("SELECT COUNT(*) AS n FROM replies WHERE device_id = ? AND created_at > ?", deviceId, dayAgo)
      .one().n;
    if (count >= MAX_REPLIES_PER_DAY) return bad("daily limit reached", "rate_limited", 429);

    const id = crypto.randomUUID();
    const now = Date.now();
    this.ctx.storage.sql.exec(
      `INSERT INTO replies (id, request_id, device_id, nickname, movie_id, movie_title, poster_path, text, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      id, requestId, deviceId, nickname, movieId, movieTitle, posterPath, trimmed || null, now,
    );

    return Response.json({
      reply: {
        id, nickname, movieId, movieTitle, posterPath,
        text: trimmed || null, createdAt: now, helpfulCount: 0,
        isMine: true, markedHelpful: false,
      },
    });
  }

  private markHelpful(body: unknown): Response {
    const { deviceId, replyId } = (body ?? {}) as Record<string, string>;
    if (!deviceId || !replyId) return bad("missing fields");

    const rows = this.ctx.storage.sql.exec<ReplyRow>(
      "SELECT * FROM replies WHERE id = ? AND hidden = 0", replyId,
    ).toArray();
    if (rows.length === 0) return bad("not found", "not_found", 404);
    const reply = rows[0];

    // Only the author of the request can mark its replies as helpful,
    // and never their own reply.
    const owner = this.ctx.storage.sql
      .exec<{ device_id: string }>("SELECT device_id FROM requests WHERE id = ?", reply.request_id)
      .toArray();
    if (owner.length === 0 || owner[0].device_id !== deviceId) return bad("not allowed", "forbidden", 403);
    if (reply.device_id === deviceId) return bad("own reply", "forbidden", 403);

    this.ctx.storage.sql.exec(
      "INSERT OR IGNORE INTO helpful (reply_id, device_id, created_at) VALUES (?, ?, ?)",
      replyId, deviceId, Date.now(),
    );

    const helpfulCount = this.ctx.storage.sql
      .exec<{ n: number }>("SELECT COUNT(*) AS n FROM helpful WHERE reply_id = ?", replyId)
      .one().n;
    return Response.json({ ok: true, helpfulCount });
  }

  // MARK: Profile, reports, activity

  private profile(url: URL): Response {
    const deviceId = url.searchParams.get("deviceId") ?? "";
    if (!deviceId) return bad("missing deviceId");

    const helpfulReceived = this.ctx.storage.sql
      .exec<{ n: number }>(
        `SELECT COUNT(*) AS n FROM helpful h JOIN replies p ON p.id = h.reply_id WHERE p.device_id = ?`,
        deviceId,
      ).one().n;
    const requestsPublished = this.ctx.storage.sql
      .exec<{ n: number }>("SELECT COUNT(*) AS n FROM requests WHERE device_id = ?", deviceId)
      .one().n;
    const repliesGiven = this.ctx.storage.sql
      .exec<{ n: number }>("SELECT COUNT(*) AS n FROM replies WHERE device_id = ?", deviceId)
      .one().n;

    return Response.json({ helpfulReceived, requestsPublished, repliesGiven });
  }

  private report(body: unknown): Response {
    const { deviceId, targetType, targetId } = (body ?? {}) as Record<string, string>;
    if (!deviceId || !targetId || (targetType !== "request" && targetType !== "reply")) {
      return bad("missing fields");
    }

    this.ctx.storage.sql.exec(
      "INSERT OR IGNORE INTO reports (target_type, target_id, device_id, created_at) VALUES (?, ?, ?, ?)",
      targetType, targetId, deviceId, Date.now(),
    );

    const reportCount = this.ctx.storage.sql
      .exec<{ n: number }>("SELECT COUNT(*) AS n FROM reports WHERE target_type = ? AND target_id = ?", targetType, targetId)
      .one().n;

    let hidden = false;
    if (reportCount >= REPORT_HIDE_THRESHOLD) {
      hidden = true;
      const table = targetType === "request" ? "requests" : "replies";
      this.ctx.storage.sql.exec(`UPDATE ${table} SET hidden = 1 WHERE id = ?`, targetId);
      if (targetType === "request") {
        this.ctx.storage.sql.exec("UPDATE replies SET hidden = 1 WHERE request_id = ?", targetId);
      }
    }
    return Response.json({ ok: true, hidden });
  }

  private activity(url: URL): Response {
    const deviceId = url.searchParams.get("deviceId") ?? "";
    const since = Number(url.searchParams.get("since") ?? 0);
    const mood = url.searchParams.get("mood");
    if (!deviceId) return bad("missing deviceId");

    // New replies to my requests since the last check (excluding my own).
    const newReplies = this.ctx.storage.sql
      .exec<{ n: number }>(
        `SELECT COUNT(*) AS n FROM replies p
         JOIN requests r ON r.id = p.request_id
         WHERE r.device_id = ? AND p.device_id != ? AND p.hidden = 0 AND p.created_at > ?`,
        deviceId, deviceId, since,
      ).one().n;

    // Requests published in the last 24h by others matching my top mood.
    let moodMatches = 0;
    if (mood && VALID_MOODS.has(mood)) {
      const dayAgo = Date.now() - 24 * 60 * 60 * 1000;
      moodMatches = this.ctx.storage.sql
        .exec<{ n: number }>(
          `SELECT COUNT(*) AS n FROM requests
           WHERE mood = ? AND device_id != ? AND hidden = 0 AND created_at > ?`,
          mood, deviceId, dayAgo,
        ).one().n;
    }

    return Response.json({ newReplies, moodMatches, now: Date.now() });
  }

  /**
   * Anonymous aggregate stats for the "moods of the week" card:
   * request counts per mood over the last 7 days plus all-time totals.
   * No device ids or texts are exposed.
   */
  private stats(): Response {
    const weekAgo = Date.now() - 7 * 24 * 60 * 60 * 1000;

    const moods = this.ctx.storage.sql
      .exec<{ mood: string; n: number }>(
        `SELECT mood, COUNT(*) AS n FROM requests
         WHERE hidden = 0 AND created_at > ?
         GROUP BY mood ORDER BY n DESC`,
        weekAgo,
      )
      .toArray();

    const totalRequests = this.ctx.storage.sql
      .exec<{ n: number }>("SELECT COUNT(*) AS n FROM requests WHERE hidden = 0")
      .one().n;
    const totalReplies = this.ctx.storage.sql
      .exec<{ n: number }>("SELECT COUNT(*) AS n FROM replies WHERE hidden = 0")
      .one().n;

    return Response.json({
      moods: moods.map((row) => ({ mood: row.mood, count: row.n })),
      totalRequests,
      totalReplies,
    });
  }

  private requestJSON(row: RequestRow, deviceId: string) {
    return {
      id: row.id,
      nickname: row.nickname,
      mood: row.mood,
      text: row.text,
      createdAt: row.created_at,
      replyCount: row.reply_count,
      isMine: row.device_id === deviceId,
    };
  }
}
