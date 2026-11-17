// Google kimlik doğrulama: servis hesabıyla erişim anahtarı alma ve
// Firebase Authentication kimlik anahtarını (ID token) doğrulama.
// Yalnızca Web Crypto API kullanır; Cloudflare Workers ve Node 20+ ile çalışır.

const TOKEN_SCOPES = [
  "https://www.googleapis.com/auth/datastore",
  "https://www.googleapis.com/auth/firebase.messaging",
].join(" ");

const SECURETOKEN_JWKS =
  "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";

const encoder = new TextEncoder();
const decoder = new TextDecoder();

export function base64UrlEncode(input) {
  const bytes = typeof input === "string" ? encoder.encode(input) : new Uint8Array(input);
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export function base64UrlDecode(input) {
  const padded = input.replace(/-/g, "+").replace(/_/g, "/") +
    "=".repeat((4 - (input.length % 4)) % 4);
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

function pemToArrayBuffer(pem) {
  const body = pem
    .replace(/-----BEGIN [^-]+-----/, "")
    .replace(/-----END [^-]+-----/, "")
    .replace(/\s+/g, "");
  return base64UrlDecode(body.replace(/\+/g, "-").replace(/\//g, "_")).buffer;
}

const RSA = { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" };

/** Servis hesabı JSON'unu ayrıştırır ve zorunlu alanları denetler. */
export function parseServiceAccount(raw) {
  let sa;
  try {
    sa = typeof raw === "string" ? JSON.parse(raw) : raw;
  } catch (_) {
    // Bazı araçlar özel anahtardaki "\n" kaçışlarını gerçek satır sonuna çevirir.
    try {
      sa = JSON.parse(String(raw).replace(/\r?\n/g, "\\n"));
    } catch (_) {
      throw new Error("GOOGLE_SERVICE_ACCOUNT geçerli bir JSON değil");
    }
  }
  for (const key of ["client_email", "private_key"]) {
    if (!sa || typeof sa[key] !== "string" || !sa[key]) {
      throw new Error(`GOOGLE_SERVICE_ACCOUNT içinde ${key} eksik`);
    }
  }
  return {
    clientEmail: sa.client_email,
    privateKey: sa.private_key,
    tokenUri: sa.token_uri || "https://oauth2.googleapis.com/token",
  };
}

/**
 * Servis hesabıyla OAuth erişim anahtarı üretir. Anahtar süresi dolana kadar
 * önbellekte tutulur (aynı Worker örneği içinde).
 */
export function createAccessTokenProvider(serviceAccount, { fetchFn = fetch, clock = () => Date.now() } = {}) {
  const sa = parseServiceAccount(serviceAccount);
  let cached = null;
  let keyPromise = null;

  const signingKey = () => {
    keyPromise ??= crypto.subtle.importKey(
      "pkcs8",
      pemToArrayBuffer(sa.privateKey),
      RSA,
      false,
      ["sign"],
    );
    return keyPromise;
  };

  return async function getAccessToken() {
    const nowMs = clock();
    if (cached && cached.expiresAt - 60_000 > nowMs) return cached.token;

    const iat = Math.floor(nowMs / 1000);
    const header = base64UrlEncode(JSON.stringify({ alg: "RS256", typ: "JWT" }));
    const claims = base64UrlEncode(JSON.stringify({
      iss: sa.clientEmail,
      scope: TOKEN_SCOPES,
      aud: sa.tokenUri,
      iat,
      exp: iat + 3600,
    }));
    const unsigned = `${header}.${claims}`;
    const signature = await crypto.subtle.sign(RSA.name, await signingKey(), encoder.encode(unsigned));
    const assertion = `${unsigned}.${base64UrlEncode(signature)}`;

    const res = await fetchFn(sa.tokenUri, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: `grant_type=${encodeURIComponent("urn:ietf:params:oauth:grant-type:jwt-bearer")}` +
        `&assertion=${encodeURIComponent(assertion)}`,
    });
    if (!res.ok) {
      throw new Error(`Erişim anahtarı alınamadı (${res.status}): ${(await res.text()).slice(0, 200)}`);
    }
    const body = await res.json();
    cached = { token: body.access_token, expiresAt: nowMs + (Number(body.expires_in) || 3600) * 1000 };
    return cached.token;
  };
}

/**
 * Firebase Authentication kimlik anahtarını doğrular ve içindeki bilgileri döner.
 * Geçersizse hata fırlatır.
 */
export function createIdTokenVerifier(projectId, { fetchFn = fetch, clock = () => Date.now() } = {}) {
  let jwks = null; // { keys: Map<kid, CryptoKey>, expiresAt }

  async function keyFor(kid) {
    const nowMs = clock();
    if (!jwks || jwks.expiresAt <= nowMs || !jwks.keys.has(kid)) {
      const res = await fetchFn(SECURETOKEN_JWKS);
      if (!res.ok) throw new Error(`Doğrulama anahtarları alınamadı (${res.status})`);
      const body = await res.json();
      const maxAge = Number(/max-age=(\d+)/.exec(res.headers.get("cache-control") || "")?.[1] || 3600);
      const keys = new Map();
      for (const jwk of body.keys || []) {
        keys.set(jwk.kid, await crypto.subtle.importKey("jwk", jwk, RSA, false, ["verify"]));
      }
      jwks = { keys, expiresAt: nowMs + maxAge * 1000 };
    }
    const key = jwks.keys.get(kid);
    if (!key) throw new Error("Bilinmeyen anahtar kimliği");
    return key;
  }

  return async function verifyIdToken(idToken) {
    const parts = String(idToken || "").split(".");
    if (parts.length !== 3) throw new Error("Geçersiz kimlik anahtarı");
    const [h, p, s] = parts;
    const header = JSON.parse(decoder.decode(base64UrlDecode(h)));
    if (header.alg !== "RS256" || !header.kid) throw new Error("Desteklenmeyen kimlik anahtarı");

    const valid = await crypto.subtle.verify(
      RSA.name,
      await keyFor(header.kid),
      base64UrlDecode(s),
      encoder.encode(`${h}.${p}`),
    );
    if (!valid) throw new Error("İmza geçersiz");

    const claims = JSON.parse(decoder.decode(base64UrlDecode(p)));
    const now = Math.floor(clock() / 1000);
    if (claims.aud !== projectId) throw new Error("Anahtar bu projeye ait değil");
    if (claims.iss !== `https://securetoken.google.com/${projectId}`) throw new Error("Anahtarı veren geçersiz");
    if (typeof claims.sub !== "string" || !claims.sub) throw new Error("Kullanıcı kimliği yok");
    if (!(claims.exp > now)) throw new Error("Anahtarın süresi dolmuş");
    if (claims.iat > now + 300) throw new Error("Anahtar gelecekte üretilmiş");
    return claims;
  };
}
