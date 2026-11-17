import { test } from "node:test";
import assert from "node:assert/strict";
import {
  base64UrlDecode,
  base64UrlEncode,
  createAccessTokenProvider,
  createIdTokenVerifier,
  parseServiceAccount,
} from "../src/google-auth.js";

const RSA = { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" };
const keyPair = await crypto.subtle.generateKey(
  { ...RSA, modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]) },
  true,
  ["sign", "verify"],
);
const pkcs8 = Buffer.from(await crypto.subtle.exportKey("pkcs8", keyPair.privateKey)).toString("base64");
const pem = `-----BEGIN PRIVATE KEY-----\n${pkcs8.match(/.{1,64}/g).join("\n")}\n-----END PRIVATE KEY-----\n`;
const serviceAccount = JSON.stringify({
  client_email: "bildirim@demo.iam.gserviceaccount.com",
  private_key: pem,
  token_uri: "https://oauth2.googleapis.com/token",
});

const jsonResponse = (body, init = {}) =>
  new Response(JSON.stringify(body), { status: 200, headers: { "Content-Type": "application/json" }, ...init });

async function sign(claims, kid = "k1") {
  const h = base64UrlEncode(JSON.stringify({ alg: "RS256", kid, typ: "JWT" }));
  const p = base64UrlEncode(JSON.stringify(claims));
  const s = await crypto.subtle.sign(RSA.name, keyPair.privateKey, new TextEncoder().encode(`${h}.${p}`));
  return `${h}.${p}.${base64UrlEncode(s)}`;
}

test("servis hesabı eksik alanla reddedilir", () => {
  assert.throws(() => parseServiceAccount("{}"), /client_email/);
  assert.throws(() => parseServiceAccount("bozuk"), /JSON/);
});

test("erişim anahtarı imzalı JWT ile alınır ve önbelleğe alınır", async () => {
  const requests = [];
  const fetchFn = async (url, init) => {
    requests.push({ url, init });
    return jsonResponse({ access_token: "ya29.test", expires_in: 3600 });
  };
  const getToken = createAccessTokenProvider(serviceAccount, { fetchFn, clock: () => 1_700_000_000_000 });
  assert.equal(await getToken(), "ya29.test");
  assert.equal(await getToken(), "ya29.test");
  assert.equal(requests.length, 1);

  const assertion = new URLSearchParams(requests[0].init.body).get("assertion");
  const [h, p, s] = assertion.split(".");
  const ok = await crypto.subtle.verify(RSA.name, keyPair.publicKey, base64UrlDecode(s), new TextEncoder().encode(`${h}.${p}`));
  assert.ok(ok, "imza doğrulanmalı");
  const claims = JSON.parse(new TextDecoder().decode(base64UrlDecode(p)));
  assert.equal(claims.iss, "bildirim@demo.iam.gserviceaccount.com");
  assert.match(claims.scope, /firebase\.messaging/);
  assert.match(claims.scope, /datastore/);
});

test("kimlik anahtarı doğrulama: geçerli, yanlış proje, süresi dolmuş, bozuk imza", async () => {
  const jwk = { ...(await crypto.subtle.exportKey("jwk", keyPair.publicKey)), kid: "k1", alg: "RS256", use: "sig" };
  let jwkFetches = 0;
  const fetchFn = async () => {
    jwkFetches++;
    return jsonResponse({ keys: [jwk] }, { headers: { "cache-control": "public, max-age=3600" } });
  };
  const nowSec = 1_700_000_000;
  const verify = createIdTokenVerifier("demo-proje", { fetchFn, clock: () => nowSec * 1000 });
  const base = {
    aud: "demo-proje",
    iss: "https://securetoken.google.com/demo-proje",
    sub: "uid-1",
    iat: nowSec - 10,
    exp: nowSec + 3000,
    email: "a@b.com",
    email_verified: true,
  };

  const claims = await verify(await sign(base));
  assert.equal(claims.sub, "uid-1");
  await verify(await sign(base));
  assert.equal(jwkFetches, 1, "anahtarlar önbellekten kullanılmalı");

  await assert.rejects(verify(await sign({ ...base, aud: "baska-proje" })), /projeye/);
  await assert.rejects(verify(await sign({ ...base, exp: nowSec - 1 })), /süresi/);
  await assert.rejects(verify(await sign({ ...base, iss: "https://evil" })), /veren/);
  await assert.rejects(verify(await sign(base, "bilinmeyen")), /anahtar/);
  const token = await sign(base);
  const tampered = token.slice(0, token.lastIndexOf(".") + 1) + base64UrlEncode(new Uint8Array(256));
  await assert.rejects(verify(tampered), /İmza/);
  await assert.rejects(verify("abc"), /Geçersiz/);
});
