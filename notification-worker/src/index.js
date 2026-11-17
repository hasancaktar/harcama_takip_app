// Harcama Takip bildirim sunucusu (Cloudflare Worker).
//
// - POST /send  { campaignId }  — Yönetim panelinden gönderilen bildirimi hemen işler.
//   İstek, yöneticinin Firebase kimlik anahtarıyla (Authorization: Bearer) gelmelidir.
// - Zamanlayıcı (dakikada bir) — günlük hatırlatmayı gönderir, bekleyen veya yarım
//   kalmış gönderimleri sürdürür. /send çağrısı başarısız olsa da bildirim en geç
//   bir dakika içinde gider.
// - GET /health — durum denetimi.

import notifications from "../../functions/lib/notifications.js";
import { createAccessTokenProvider, createIdTokenVerifier } from "./google-auth.js";
import { FirestoreStore } from "./firestore.js";
import { createFcmSender } from "./fcm.js";
import { DEFAULT_CHUNK_SIZE, processCampaign, runScheduled } from "./delivery.js";

// Worker örneği yaşadıkça erişim anahtarı ve doğrulama anahtarları önbellekte kalır.
let cache = null;

export function createDeps(env, { fetchFn = (...a) => fetch(...a) } = {}) {
  if (cache && cache.env === env) return cache.deps;
  const projectId = env.PROJECT_ID;
  if (!projectId) throw new Error("PROJECT_ID tanımlı değil");
  const getAccessToken = createAccessTokenProvider(env.GOOGLE_SERVICE_ACCOUNT, { fetchFn });
  const deps = {
    store: new FirestoreStore({ projectId, getAccessToken, fetchFn }),
    send: createFcmSender({ projectId, getAccessToken, fetchFn }),
    verifyIdToken: createIdTokenVerifier(projectId, { fetchFn }),
    chunkSize: Number(env.CHUNK_SIZE) || DEFAULT_CHUNK_SIZE,
  };
  cache = { env, fetchFn, deps };
  return deps;
}

function corsHeaders(request, env) {
  const origin = request.headers.get("Origin") || "";
  const allowed = String(env.ALLOWED_ORIGINS || "").split(",").map((s) => s.trim()).filter(Boolean);
  const ok = allowed.includes(origin) || /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin);
  return ok
    ? {
      "Access-Control-Allow-Origin": origin,
      "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
      "Access-Control-Allow-Headers": "Authorization, Content-Type",
      "Access-Control-Max-Age": "86400",
      Vary: "Origin",
    }
    : {};
}

const json = (status, body, headers = {}) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8", ...headers },
  });

/** Kimlik anahtarı doğrulanmış, e-postası doğrulanmış yönetici mi? */
export function isAdminClaims(claims) {
  return !!claims &&
    claims.email_verified === true &&
    String(claims.email || "").toLowerCase() === notifications.ADMIN_EMAIL;
}

export async function handleFetch(request, env, deps) {
  const url = new URL(request.url);
  const cors = corsHeaders(request, env);

  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
  if (request.method === "GET" && url.pathname === "/health") return json(200, { ok: true }, cors);
  if (request.method !== "POST" || url.pathname !== "/send") return json(404, { error: "not_found" }, cors);

  const auth = request.headers.get("Authorization") || "";
  if (!auth.startsWith("Bearer ")) return json(401, { error: "unauthenticated" }, cors);
  let claims;
  try {
    claims = await deps.verifyIdToken(auth.slice(7));
  } catch (_) {
    return json(401, { error: "unauthenticated" }, cors);
  }
  if (!isAdminClaims(claims)) return json(403, { error: "forbidden" }, cors);

  let body;
  try {
    body = await request.json();
  } catch (_) {
    return json(400, { error: "invalid_body" }, cors);
  }
  const campaignId = typeof body?.campaignId === "string" ? body.campaignId : "";
  if (!/^[A-Za-z0-9_-]{1,64}$/.test(campaignId)) return json(400, { error: "invalid_campaign" }, cors);

  const campaign = await deps.store.getCampaign(campaignId);
  if (!campaign) return json(404, { error: "campaign_not_found" }, cors);
  // Yalnızca isteği yapan yöneticinin kendi oluşturduğu kampanya işlenir.
  if (campaign.data.createdBy !== claims.sub) return json(403, { error: "forbidden" }, cors);

  const result = await processCampaign({
    store: deps.store,
    send: deps.send,
    campaign,
    chunkSize: deps.chunkSize,
  });
  return json(200, result, cors);
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method === "GET" && url.pathname === "/health") {
      // Gizli değerleri göstermeden yapılandırmanın tamam olup olmadığını bildirir.
      let configured = true;
      try {
        createDeps(env);
      } catch (_) {
        configured = false;
      }
      return json(configured ? 200 : 503, { ok: configured, configured }, corsHeaders(request, env));
    }
    try {
      return await handleFetch(request, env, createDeps(env));
    } catch (e) {
      console.error("İstek işlenemedi", e);
      return json(500, { error: "internal" }, corsHeaders(request, env));
    }
  },

  async scheduled(_event, env, ctx) {
    const deps = createDeps(env);
    ctx.waitUntil(
      runScheduled({ store: deps.store, send: deps.send, chunkSize: deps.chunkSize })
        .then((r) => {
          if (r.processed || r.queuedDaily) console.log("Zamanlanmış çalışma", JSON.stringify(r));
        })
        .catch((e) => console.error("Zamanlanmış çalışma başarısız", e)),
    );
  },
};
