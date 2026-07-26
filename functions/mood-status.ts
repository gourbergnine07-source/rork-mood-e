import { DurableObject } from "cloudflare:workers";
import { isCleanText } from "./moderation";

/**
 * "Stato Mood": ephemeral, anonymous movie statuses (24h) inspired by
 * stories. Users publish a favorite movie (TMDB poster + title, never a
 * personal photo/video) with an optional short comment. Others can view,
 * leave short public comments or quick emoji reactions.
 *
 * Anonymity model mirrors the advice board: users are identified only by
 * an opaque random device id and a self-generated nickname. Each device
 * additionally gets a random public author id so statuses can be grouped
 * per author in the feed without ever exposing the device id.
 */

const STATUS_TTL_MS = 24 * 60 * 60 * 1000;
const MAX_STATUS_TEXT = 150;
const MAX_COMMENT_TEXT = 100;
const MAX_NICKNAME = 30;
const MAX_STATUSES_PER_DAY = 5;
const MAX_COMMENTS_PER_DAY = 60;
const REPORT_HIDE_THRESHOLD = 3;
const ALLOWED_REACTIONS = new Set(["❤️", "🔥", "😂", "👀"]);
/** Hour of day (UTC) at which the nightly purge alarm fires. */
const MAINTENANCE_HOUR_UTC = 4;

type Env = {
  DO: Fetcher & {
    setAlarm(className: string, id: string, scheduledTime: number | Date): Promise<void>;
    getAlarm(className: string, id: string): Promise<number | null>;
    deleteAlarm(className: string, id: string): Promise<void>;
  };
};

type StatusRow = {
  id: string;
  device_id: string;
  author_id: string;
  nickname: string;
  movie_id: number;
  movie_title: string;
  poster_path: string | null;
  text: string | null;
  created_at: number;
  expires_at: number;
};

type CommentRow = {
  id: string;
  status_id: string;
  device_id: string;
  nickname: string;
  text: string;
  created_at: number;
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

export class MoodStatusBoard extends DurableObject<Env> {
  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    this.ctx.storage.sql.exec(`
      CREATE TABLE IF NOT EXISTS authors (
        device_id TEXT PRIMARY KEY,
        author_id TEXT NOT NULL
      );
      CREATE TABLE IF NOT EXISTS statuses (
        id TEXT PRIMARY KEY,
        device_id TEXT NOT NULL,
        nickname TEXT NOT NULL,
        movie_id INTEGER NOT NULL,
        movie_title TEXT NOT NULL,
        poster_path TEXT,
        text TEXT,
        created_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL,
        hidden INTEGER NOT NULL DEFAULT 0
      );
      CREATE TABLE IF NOT EXISTS views (
        status_id TEXT NOT NULL,
        device_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (status_id, device_id)
      );
      CREATE TABLE IF NOT EXISTS comments (
        id TEXT PRIMARY KEY,
        status_id TEXT NOT NULL,
        device_id TEXT NOT NULL,
        nickname TEXT NOT NULL,
        text TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        hidden INTEGER NOT NULL DEFAULT 0
      );
      CREATE TABLE IF NOT EXISTS reactions (
        status_id TEXT NOT NULL,
        device_id TEXT NOT NULL,
        nickname TEXT NOT NULL,
        emoji TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (status_id, device_id)
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
      if (method === "GET" && path === "/status/feed") {
        return this.feed(url);
      }
      if (method === "POST" && path === "/status/publish") {
        return this.publish(await request.json());
      }
      if (method === "POST" && path === "/status/view") {
        return this.recordView(await request.json());
      }
      if (method === "GET" && path === "/status/comments") {
        return this.listComments(url);
      }
      if (method === "POST" && path === "/status/comment") {
        return this.createComment(await request.json());
      }
      if (method === "POST" && path === "/status/react") {
        return this.react(await request.json());
      }
      if (method === "GET" && path === "/status/insights") {
        return this.insights(url);
      }
      if (method === "POST" && path === "/status/report") {
        return this.report(await request.json());
      }
      return new Response("not found", { status: 404 });
    } catch (error) {
      console.error("MoodStatusBoard error", path, error);
      return bad("internal error", "internal", 500);
    } finally {
      this.ctx.waitUntil(this.ensureMaintenanceAlarm());
    }
  }

  // MARK: Scheduled cleanup

  private async ensureMaintenanceAlarm(): Promise<void> {
    try {
      const pending = await this.env.DO.getAlarm("MoodStatusBoard", this.ctx.id.name ?? "global");
      if (pending === null) {
        await this.env.DO.setAlarm("MoodStatusBoard", this.ctx.id.name ?? "global", nextMaintenanceTime());
      }
    } catch (error) {
      console.warn("MoodStatusBoard ensureMaintenanceAlarm failed", error);
    }
  }

  /**
   * Nightly purge: expired statuses disappear from every query instantly
   * (all reads filter on expires_at), this task just deletes the rows and
   * their comments/reactions/views/reports so old content never piles up.
   */
  async onAlarm(info: { scheduledTime: number; retryCount: number; isRetry: boolean }): Promise<void> {
    if (info.isRetry) console.warn(`MoodStatusBoard maintenance retry #${info.retryCount}`);
    try {
      const now = Date.now();
      const sql = this.ctx.storage.sql;
      sql.exec("DELETE FROM comments WHERE status_id IN (SELECT id FROM statuses WHERE expires_at < ?)", now);
      sql.exec("DELETE FROM reactions WHERE status_id IN (SELECT id FROM statuses WHERE expires_at < ?)", now);
      sql.exec("DELETE FROM views WHERE status_id IN (SELECT id FROM statuses WHERE expires_at < ?)", now);
      sql.exec(
        `DELETE FROM reports WHERE
         (target_type = 'status' AND target_id IN (SELECT id FROM statuses WHERE expires_at < ?)) OR
         (target_type = 'comment' AND target_id NOT IN (SELECT id FROM comments))`,
        now,
      );
      sql.exec("DELETE FROM statuses WHERE expires_at < ?", now);
      const remaining = sql.exec<{ n: number }>("SELECT COUNT(*) AS n FROM statuses").one().n;
      console.log(`MoodStatusBoard maintenance done: ${remaining} active statuses`);
    } finally {
      await this.env.DO.setAlarm("MoodStatusBoard", this.ctx.id.name ?? "global", nextMaintenanceTime());
    }
  }

  // MARK: Authors

  /** Stable random public id for a device, so the feed can group statuses. */
  private authorId(deviceId: string): string {
    const rows = this.ctx.storage.sql
      .exec<{ author_id: string }>("SELECT author_id FROM authors WHERE device_id = ?", deviceId)
      .toArray();
    if (rows.length > 0) return rows[0].author_id;
    const fresh = crypto.randomUUID();
    this.ctx.storage.sql.exec("INSERT INTO authors (device_id, author_id) VALUES (?, ?)", deviceId, fresh);
    return fresh;
  }

  // MARK: Feed

  /**
   * Active statuses grouped per anonymous author.
   * Personalized: includes seen flags, own reaction, and view counts for
   * the caller's own statuses only.
   */
  private feed(url: URL): Response {
    const deviceId = url.searchParams.get("deviceId") ?? "";
    const now = Date.now();

    const rows = this.ctx.storage.sql.exec<StatusRow & { author_id: string }>(
      `SELECT s.*, a.author_id FROM statuses s
       JOIN authors a ON a.device_id = s.device_id
       WHERE s.hidden = 0 AND s.expires_at > ?
       ORDER BY s.created_at ASC`,
      now,
    ).toArray();

    const seenIds = new Set(
      this.ctx.storage.sql
        .exec<{ status_id: string }>("SELECT status_id FROM views WHERE device_id = ?", deviceId)
        .toArray()
        .map((row) => row.status_id),
    );
    const myReactions = new Map(
      this.ctx.storage.sql
        .exec<{ status_id: string; emoji: string }>("SELECT status_id, emoji FROM reactions WHERE device_id = ?", deviceId)
        .toArray()
        .map((row) => [row.status_id, row.emoji]),
    );

    type Group = {
      authorId: string;
      nickname: string;
      isMine: boolean;
      statuses: Record<string, unknown>[];
    };
    const groups = new Map<string, Group>();

    for (const row of rows) {
      let group = groups.get(row.author_id);
      if (!group) {
        group = {
          authorId: row.author_id,
          nickname: row.nickname,
          isMine: row.device_id === deviceId,
          statuses: [],
        };
        groups.set(row.author_id, group);
      }
      // Latest nickname wins (user may regenerate it between statuses).
      group.nickname = row.nickname;

      const reactionCounts = this.reactionCounts(row.id);
      const commentCount = this.ctx.storage.sql
        .exec<{ n: number }>("SELECT COUNT(*) AS n FROM comments WHERE status_id = ? AND hidden = 0", row.id)
        .one().n;

      const status: Record<string, unknown> = {
        id: row.id,
        movieId: row.movie_id,
        movieTitle: row.movie_title,
        posterPath: row.poster_path,
        text: row.text,
        createdAt: row.created_at,
        expiresAt: row.expires_at,
        seen: seenIds.has(row.id) || row.device_id === deviceId,
        commentCount,
        reactionCounts,
        myReaction: myReactions.get(row.id) ?? null,
      };
      if (row.device_id === deviceId) {
        status.viewCount = this.viewCount(row.id, row.device_id);
      }
      group.statuses.push(status);
    }

    // Own group first, then groups with unseen statuses, newest activity first.
    const ordered = Array.from(groups.values()).sort((a, b) => {
      if (a.isMine !== b.isMine) return a.isMine ? -1 : 1;
      const unseenA = a.statuses.some((s) => s.seen === false);
      const unseenB = b.statuses.some((s) => s.seen === false);
      if (unseenA !== unseenB) return unseenA ? -1 : 1;
      const lastA = Number(a.statuses[a.statuses.length - 1]?.createdAt ?? 0);
      const lastB = Number(b.statuses[b.statuses.length - 1]?.createdAt ?? 0);
      return lastB - lastA;
    });

    return Response.json({ groups: ordered, now });
  }

  private reactionCounts(statusId: string): Record<string, number> {
    const rows = this.ctx.storage.sql
      .exec<{ emoji: string; n: number }>(
        "SELECT emoji, COUNT(*) AS n FROM reactions WHERE status_id = ? GROUP BY emoji",
        statusId,
      )
      .toArray();
    const counts: Record<string, number> = {};
    for (const row of rows) counts[row.emoji] = row.n;
    return counts;
  }

  /** Views by others (the author's own openings are not counted). */
  private viewCount(statusId: string, authorDeviceId: string): number {
    return this.ctx.storage.sql
      .exec<{ n: number }>(
        "SELECT COUNT(*) AS n FROM views WHERE status_id = ? AND device_id != ?",
        statusId, authorDeviceId,
      ).one().n;
  }

  // MARK: Publish

  private publish(body: unknown): Response {
    const { deviceId, nickname, movieTitle } = (body ?? {}) as Record<string, string>;
    const movieId = Number((body as Record<string, unknown>)?.movieId ?? 0);
    const posterPath = ((body as Record<string, unknown>)?.posterPath as string | undefined) ?? null;
    const rawText = ((body as Record<string, unknown>)?.text as string | undefined) ?? "";

    if (!deviceId || !nickname || !movieTitle || !movieId) return bad("missing fields");
    if (nickname.length > MAX_NICKNAME) return bad("nickname too long");
    const trimmed = rawText.trim().slice(0, MAX_STATUS_TEXT);
    if (!isCleanText(trimmed) || !isCleanText(nickname) || !isCleanText(movieTitle)) {
      return bad("offensive content", "offensive");
    }

    const dayAgo = Date.now() - 24 * 60 * 60 * 1000;
    const count = this.ctx.storage.sql
      .exec<{ n: number }>("SELECT COUNT(*) AS n FROM statuses WHERE device_id = ? AND created_at > ?", deviceId, dayAgo)
      .one().n;
    if (count >= MAX_STATUSES_PER_DAY) return bad("daily limit reached", "rate_limited", 429);

    const id = crypto.randomUUID();
    const now = Date.now();
    const expiresAt = now + STATUS_TTL_MS;
    this.authorId(deviceId);
    this.ctx.storage.sql.exec(
      `INSERT INTO statuses (id, device_id, nickname, movie_id, movie_title, poster_path, text, created_at, expires_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      id, deviceId, nickname, movieId, movieTitle, posterPath, trimmed || null, now, expiresAt,
    );

    return Response.json({
      status: {
        id, movieId, movieTitle, posterPath,
        text: trimmed || null, createdAt: now, expiresAt,
        seen: true, commentCount: 0, reactionCounts: {}, myReaction: null, viewCount: 0,
      },
    });
  }

  // MARK: Views

  private recordView(body: unknown): Response {
    const { deviceId, statusId } = (body ?? {}) as Record<string, string>;
    if (!deviceId || !statusId) return bad("missing fields");
    const exists = this.ctx.storage.sql
      .exec<{ device_id: string }>(
        "SELECT device_id FROM statuses WHERE id = ? AND hidden = 0 AND expires_at > ?",
        statusId, Date.now(),
      ).toArray();
    if (exists.length === 0) return bad("not found", "not_found", 404);

    this.ctx.storage.sql.exec(
      "INSERT OR IGNORE INTO views (status_id, device_id, created_at) VALUES (?, ?, ?)",
      statusId, deviceId, Date.now(),
    );
    return Response.json({ ok: true });
  }

  // MARK: Comments

  private listComments(url: URL): Response {
    const statusId = url.searchParams.get("statusId") ?? "";
    const deviceId = url.searchParams.get("deviceId") ?? "";
    if (!statusId) return bad("missing statusId");

    const rows = this.ctx.storage.sql.exec<CommentRow>(
      `SELECT * FROM comments WHERE status_id = ? AND hidden = 0 ORDER BY created_at ASC LIMIT 200`,
      statusId,
    ).toArray();

    return Response.json({
      comments: rows.map((row) => ({
        id: row.id,
        nickname: row.nickname,
        text: row.text,
        createdAt: row.created_at,
        isMine: row.device_id === deviceId,
      })),
    });
  }

  private createComment(body: unknown): Response {
    const { deviceId, nickname, statusId, text } = (body ?? {}) as Record<string, string>;
    if (!deviceId || !nickname || !statusId || !text) return bad("missing fields");
    if (nickname.length > MAX_NICKNAME) return bad("nickname too long");
    const trimmed = text.trim();
    if (trimmed.length === 0 || trimmed.length > MAX_COMMENT_TEXT) return bad("text length");
    if (!isCleanText(trimmed) || !isCleanText(nickname)) return bad("offensive content", "offensive");

    const target = this.ctx.storage.sql
      .exec<{ id: string }>("SELECT id FROM statuses WHERE id = ? AND hidden = 0 AND expires_at > ?", statusId, Date.now())
      .toArray();
    if (target.length === 0) return bad("not found", "not_found", 404);

    const dayAgo = Date.now() - 24 * 60 * 60 * 1000;
    const count = this.ctx.storage.sql
      .exec<{ n: number }>("SELECT COUNT(*) AS n FROM comments WHERE device_id = ? AND created_at > ?", deviceId, dayAgo)
      .one().n;
    if (count >= MAX_COMMENTS_PER_DAY) return bad("daily limit reached", "rate_limited", 429);

    const id = crypto.randomUUID();
    const now = Date.now();
    this.ctx.storage.sql.exec(
      "INSERT INTO comments (id, status_id, device_id, nickname, text, created_at) VALUES (?, ?, ?, ?, ?, ?)",
      id, statusId, deviceId, nickname, trimmed, now,
    );

    return Response.json({
      comment: { id, nickname, text: trimmed, createdAt: now, isMine: true },
    });
  }

  // MARK: Reactions

  /** Sets, replaces or removes (same emoji twice) a quick reaction. */
  private react(body: unknown): Response {
    const { deviceId, nickname, statusId, emoji } = (body ?? {}) as Record<string, string>;
    if (!deviceId || !nickname || !statusId || !emoji) return bad("missing fields");
    if (!ALLOWED_REACTIONS.has(emoji)) return bad("unknown reaction");

    const target = this.ctx.storage.sql
      .exec<{ id: string }>("SELECT id FROM statuses WHERE id = ? AND hidden = 0 AND expires_at > ?", statusId, Date.now())
      .toArray();
    if (target.length === 0) return bad("not found", "not_found", 404);

    const existing = this.ctx.storage.sql
      .exec<{ emoji: string }>("SELECT emoji FROM reactions WHERE status_id = ? AND device_id = ?", statusId, deviceId)
      .toArray();

    let myReaction: string | null = emoji;
    if (existing.length > 0 && existing[0].emoji === emoji) {
      this.ctx.storage.sql.exec("DELETE FROM reactions WHERE status_id = ? AND device_id = ?", statusId, deviceId);
      myReaction = null;
    } else {
      this.ctx.storage.sql.exec(
        `INSERT INTO reactions (status_id, device_id, nickname, emoji, created_at) VALUES (?, ?, ?, ?, ?)
         ON CONFLICT (status_id, device_id) DO UPDATE SET emoji = excluded.emoji, created_at = excluded.created_at`,
        statusId, deviceId, nickname, emoji, Date.now(),
      );
    }

    return Response.json({ ok: true, myReaction, reactionCounts: this.reactionCounts(statusId) });
  }

  // MARK: Owner insights

  /**
   * Owner-only recap: how many people saw the status plus the reactions
   * received (anonymous nicknames only, never any identifying data).
   */
  private insights(url: URL): Response {
    const deviceId = url.searchParams.get("deviceId") ?? "";
    const statusId = url.searchParams.get("statusId") ?? "";
    if (!deviceId || !statusId) return bad("missing fields");

    const rows = this.ctx.storage.sql
      .exec<{ device_id: string }>("SELECT device_id FROM statuses WHERE id = ?", statusId)
      .toArray();
    if (rows.length === 0) return bad("not found", "not_found", 404);
    if (rows[0].device_id !== deviceId) return bad("not allowed", "forbidden", 403);

    const reactions = this.ctx.storage.sql
      .exec<{ nickname: string; emoji: string; created_at: number }>(
        "SELECT nickname, emoji, created_at FROM reactions WHERE status_id = ? ORDER BY created_at DESC",
        statusId,
      )
      .toArray();
    const commentCount = this.ctx.storage.sql
      .exec<{ n: number }>("SELECT COUNT(*) AS n FROM comments WHERE status_id = ? AND hidden = 0", statusId)
      .one().n;

    return Response.json({
      viewCount: this.viewCount(statusId, deviceId),
      commentCount,
      reactions: reactions.map((row) => ({
        nickname: row.nickname,
        emoji: row.emoji,
        createdAt: row.created_at,
      })),
    });
  }

  // MARK: Reports

  /** 3 independent reports hide a status or a comment. */
  private report(body: unknown): Response {
    const { deviceId, targetType, targetId } = (body ?? {}) as Record<string, string>;
    if (!deviceId || !targetId || (targetType !== "status" && targetType !== "comment")) {
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
      const table = targetType === "status" ? "statuses" : "comments";
      this.ctx.storage.sql.exec(`UPDATE ${table} SET hidden = 1 WHERE id = ?`, targetId);
    }
    return Response.json({ ok: true, hidden });
  }
}
