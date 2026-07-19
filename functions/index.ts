export { AdviceBoard } from "./advice-board";

type Env = { DO: Fetcher };

const CORS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS });
    }

    if (url.pathname === "/ping") {
      return Response.json({ ok: true, now: new Date().toISOString() });
    }

    if (url.pathname.startsWith("/advice")) {
      // Single shared community board for the whole app.
      const wrapped = new Request(request.url, request);
      wrapped.headers.set("X-Rork-DO-Class", "AdviceBoard");
      wrapped.headers.set("X-Rork-DO-Id", "global");
      const response = await env.DO.fetch(wrapped);
      const withCors = new Response(response.body, response);
      for (const [key, value] of Object.entries(CORS)) {
        withCors.headers.set(key, value);
      }
      return withCors;
    }

    return new Response("not found", { status: 404 });
  },
} satisfies ExportedHandler<Env>;
