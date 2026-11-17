import { test } from "node:test";
import assert from "node:assert/strict";
import { handleFetch, isAdminClaims } from "../src/index.js";
import { MemoryStore, fakeSender, user } from "./helpers.js";

const env = { ALLOWED_ORIGINS: "https://harcama-takip-app-7ff66.web.app" };
const ADMIN = { sub: "admin-uid", email: "hasancaktar@gmail.com", email_verified: true };

function deps({ claims = ADMIN, store } = {}) {
  const { send, sent } = fakeSender();
  return {
    store: store || new MemoryStore({
      users: [user("a", ["ta"])],
      campaigns: {
        c1: { type: "manual", titleTr: "Duyuru", bodyTr: "Merhaba", target: "all", status: "queued", createdBy: "admin-uid" },
      },
    }),
    send,
    sent,
    chunkSize: 35,
    verifyIdToken: async (t) => {
      if (t !== "iyi") throw new Error("geçersiz");
      return claims;
    },
  };
}

const post = (body, headers = {}) =>
  new Request("https://w.example/send", {
    method: "POST",
    headers: { "Content-Type": "application/json", Origin: "https://harcama-takip-app-7ff66.web.app", ...headers },
    body: JSON.stringify(body),
  });

test("yönetici denetimi: doğrulanmış ve birebir aynı e-posta", () => {
  assert.equal(isAdminClaims(ADMIN), true);
  assert.equal(isAdminClaims({ ...ADMIN, email: "HasanCaktar@gmail.com" }), true);
  assert.equal(isAdminClaims({ ...ADMIN, email_verified: false }), false);
  assert.equal(isAdminClaims({ ...ADMIN, email: "hasancaktar@gmail.com.evil" }), false);
  assert.equal(isAdminClaims(null), false);
});

test("/send: yönetici kendi kampanyasını gönderir; CORS başlığı eklenir", async () => {
  const d = deps();
  const res = await handleFetch(post({ campaignId: "c1" }, { Authorization: "Bearer iyi" }), env, d);
  assert.equal(res.status, 200);
  assert.equal((await res.json()).status, "sent");
  assert.equal(d.sent.length, 1);
  assert.equal(res.headers.get("Access-Control-Allow-Origin"), "https://harcama-takip-app-7ff66.web.app");
});

test("/send: kimliksiz, geçersiz kimlik ve yönetici olmayan reddedilir", async () => {
  const d = deps();
  assert.equal((await handleFetch(post({ campaignId: "c1" }), env, d)).status, 401);
  assert.equal((await handleFetch(post({ campaignId: "c1" }, { Authorization: "Bearer kötü" }), env, d)).status, 401);
  const other = deps({ claims: { sub: "x", email: "a@b.com", email_verified: true } });
  assert.equal((await handleFetch(post({ campaignId: "c1" }, { Authorization: "Bearer iyi" }), env, other)).status, 403);
  assert.equal(d.sent.length + other.sent.length, 0);
});

test("/send: başka hesabın oluşturduğu veya olmayan kampanya, bozuk istek", async () => {
  const store = new MemoryStore({ campaigns: { c2: { status: "queued", createdBy: "baskasi" } } });
  const d = deps({ store });
  const auth = { Authorization: "Bearer iyi" };
  assert.equal((await handleFetch(post({ campaignId: "c2" }, auth), env, d)).status, 403);
  assert.equal((await handleFetch(post({ campaignId: "yok" }, auth), env, d)).status, 404);
  assert.equal((await handleFetch(post({ campaignId: "../users/x" }, auth), env, d)).status, 400);
  assert.equal((await handleFetch(post({}, auth), env, d)).status, 400);
});

test("ön kontrol (OPTIONS), sağlık denetimi ve izinsiz köken", async () => {
  const d = deps();
  const pre = await handleFetch(new Request("https://w.example/send", {
    method: "OPTIONS",
    headers: { Origin: "https://harcama-takip-app-7ff66.web.app" },
  }), env, d);
  assert.equal(pre.status, 204);
  assert.match(pre.headers.get("Access-Control-Allow-Headers"), /Authorization/);

  const evil = await handleFetch(new Request("https://w.example/send", {
    method: "OPTIONS",
    headers: { Origin: "https://evil.example" },
  }), env, d);
  assert.equal(evil.headers.get("Access-Control-Allow-Origin"), null);

  const health = await handleFetch(new Request("https://w.example/health"), env, d);
  assert.equal(health.status, 200);
  assert.equal((await handleFetch(new Request("https://w.example/x"), env, d)).status, 404);
});
