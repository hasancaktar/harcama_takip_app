// Firebase Cloud Messaging HTTP v1: tek cihaza bildirim gönderir.

/** Cihaz anahtarı artık geçersiz mi? (Uygulama kaldırılmış, anahtar yenilenmiş vb.) */
export function isUnregistered(status, body) {
  const details = body?.error?.details || [];
  const code = details.map((d) => d.errorCode).find(Boolean);
  if (code === "UNREGISTERED") return true;
  if (status === 404) return true;
  if (code === "INVALID_ARGUMENT" || status === 400) {
    return /registration token/i.test(body?.error?.message || "");
  }
  return false;
}

export function createFcmSender({ projectId, getAccessToken, fetchFn = fetch }) {
  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

  /** @return {Promise<{ok: boolean, unregistered: boolean, error?: string}>} */
  return async function send({ token, title, body, data = {} }) {
    try {
      const res = await fetchFn(url, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${await getAccessToken()}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title, body },
            data,
            android: { priority: "HIGH", notification: { channel_id: "announcements" } },
          },
        }),
      });
      if (res.ok) return { ok: true, unregistered: false };
      let parsed = null;
      try {
        parsed = await res.json();
      } catch (_) { /* gövde JSON değil */ }
      return {
        ok: false,
        unregistered: isUnregistered(res.status, parsed),
        error: parsed?.error?.status || `HTTP ${res.status}`,
      };
    } catch (e) {
      return { ok: false, unregistered: false, error: String(e.message || e) };
    }
  };
}
