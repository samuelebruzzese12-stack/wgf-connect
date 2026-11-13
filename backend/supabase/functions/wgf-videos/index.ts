// WGF CONNECT – ultimi video del canale WhenGamersFail ► Lyon (feed RSS pubblico di YouTube).
// Restituisce solo titolo, data e link: il video si guarda su YouTube.
// Pubblicata sul progetto Supabase come funzione "wgf-videos" (verify_jwt = true).
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const CHANNEL_ID = "UC1OGV4dczjRz8wNLRaezJ5Q";
const HANDLE_URL = "https://www.youtube.com/@whengamersfail";
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

let cache: { at: number; body: string } | null = null;

function decode(s: string) {
  return s.replace(/&amp;/g, "&").replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&lt;/g, "<").replace(/&gt;/g, ">");
}

async function resolveChannelId(): Promise<string> {
  try {
    const html = await (await fetch(HANDLE_URL, { headers: { "Accept-Language": "it" } })).text();
    const m = html.match(/"externalId":"(UC[\w-]{22})"/) ?? html.match(/channel_id=(UC[\w-]{22})/);
    if (m) return m[1];
  } catch (_) { /* uso l'ID noto */ }
  return CHANNEL_ID;
}

async function load(channelId: string) {
  const res = await fetch(`https://www.youtube.com/feeds/videos.xml?channel_id=${channelId}`);
  if (!res.ok) throw new Error(`feed ${res.status}`);
  const xml = await res.text();
  const author = decode(xml.match(/<author>\s*<name>([^<]+)<\/name>/)?.[1] ?? "");
  const entries = [...xml.matchAll(/<entry>([\s\S]*?)<\/entry>/g)].slice(0, 15).map((m) => {
    const e = m[1];
    const id = e.match(/<yt:videoId>([^<]+)<\/yt:videoId>/)?.[1] ?? "";
    return {
      id,
      title: decode(e.match(/<title>([^<]+)<\/title>/)?.[1] ?? ""),
      published: e.match(/<published>([^<]+)<\/published>/)?.[1] ?? null,
      url: `https://www.youtube.com/watch?v=${id}`,
      views: Number(e.match(/<media:statistics views="(\d+)"/)?.[1] ?? 0),
    };
  });
  return { author, entries };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (cache && Date.now() - cache.at < 30 * 60 * 1000) {
    return new Response(cache.body, { headers: { ...cors, "Content-Type": "application/json" } });
  }
  try {
    let data = await load(CHANNEL_ID);
    if (!/whengamersfail|lyon/i.test(data.author)) {
      data = await load(await resolveChannelId());
    }
    const body = JSON.stringify({ channel: data.author, videos: data.entries, updated_at: new Date().toISOString() });
    cache = { at: Date.now(), body };
    return new Response(body, { headers: { ...cors, "Content-Type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e), videos: [] }), {
      status: 502,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }
});
