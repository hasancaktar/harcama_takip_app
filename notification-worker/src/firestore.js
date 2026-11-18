// Firestore REST API istemcisi (servis hesabıyla; güvenlik kurallarına tabi değildir).
// Yalnızca bildirim gönderimi için gereken işlemleri içerir.

export function encodeValue(value) {
  if (value === null || value === undefined) return { nullValue: null };
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (Array.isArray(value)) return { arrayValue: { values: value.map(encodeValue) } };
  switch (typeof value) {
    case "boolean": return { booleanValue: value };
    case "number": return Number.isInteger(value) ? { integerValue: String(value) } : { doubleValue: value };
    case "string": return { stringValue: value };
    case "object": return { mapValue: { fields: encodeFields(value) } };
    default: throw new Error(`Desteklenmeyen değer türü: ${typeof value}`);
  }
}

export function encodeFields(obj) {
  const fields = {};
  for (const [k, v] of Object.entries(obj)) {
    if (v !== undefined) fields[k] = encodeValue(v);
  }
  return fields;
}

export function decodeValue(v) {
  if (!v || typeof v !== "object") return null;
  if ("stringValue" in v) return v.stringValue;
  if ("integerValue" in v) return Number(v.integerValue);
  if ("doubleValue" in v) return Number(v.doubleValue);
  if ("booleanValue" in v) return v.booleanValue;
  if ("nullValue" in v) return null;
  if ("timestampValue" in v) return new Date(v.timestampValue);
  if ("arrayValue" in v) return (v.arrayValue.values || []).map(decodeValue);
  if ("mapValue" in v) return decodeFields(v.mapValue.fields || {});
  if ("referenceValue" in v) return v.referenceValue;
  return null;
}

export function decodeFields(fields) {
  const out = {};
  for (const [k, v] of Object.entries(fields || {})) out[k] = decodeValue(v);
  return out;
}

const idOf = (name) => name.slice(name.lastIndexOf("/") + 1);
const toDoc = (d) => ({ id: idOf(d.name), data: decodeFields(d.fields), updateTime: d.updateTime });

class PreconditionFailed extends Error {}

export class FirestoreStore {
  constructor({ projectId, getAccessToken, fetchFn = (...a) => fetch(...a) }) {
    this.projectId = projectId;
    this.getAccessToken = getAccessToken;
    // Workers'ta `fetch` bir nesnenin metodu olarak çağrılırsa "Illegal invocation"
    // hatası verir; bu yüzden bağımsız bir işlev olarak saklanır.
    const f = fetchFn;
    this.fetchFn = (...a) => f(...a);
    this.root = `projects/${projectId}/databases/(default)/documents`;
    this.base = `https://firestore.googleapis.com/v1/${this.root}`;
  }

  name(path) {
    return `${this.root}/${path}`;
  }

  async request(url, init = {}) {
    const res = await this.fetchFn(url, {
      ...init,
      headers: {
        Authorization: `Bearer ${await this.getAccessToken()}`,
        "Content-Type": "application/json",
        ...(init.headers || {}),
      },
    });
    if (res.ok) return res.json();
    const text = await res.text();
    if (res.status === 404 && (init.method || "GET") === "GET") return null;
    if (/FAILED_PRECONDITION|ABORTED/.test(text) || res.status === 409) {
      throw new PreconditionFailed(text.slice(0, 200));
    }
    throw new Error(`Firestore ${res.status}: ${text.slice(0, 300)}`);
  }

  async commit(writes) {
    return this.request(`${this.base}:commit`, { method: "POST", body: JSON.stringify({ writes }) });
  }

  async getDoc(path) {
    const doc = await this.request(`${this.base}/${path}`);
    return doc ? toDoc(doc) : null;
  }

  // ---- Bildirim kampanyaları

  getCampaign(id) {
    return this.getDoc(`notificationCampaigns/${id}`);
  }

  async findPendingCampaigns(limit = 5) {
    const rows = await this.request(`${this.base}:runQuery`, {
      method: "POST",
      body: JSON.stringify({
        structuredQuery: {
          from: [{ collectionId: "notificationCampaigns" }],
          where: {
            fieldFilter: {
              field: { fieldPath: "status" },
              op: "IN",
              value: { arrayValue: { values: [{ stringValue: "queued" }, { stringValue: "sending" }] } },
            },
          },
          limit,
        },
      }),
    });
    return (rows || []).filter((r) => r.document).map((r) => toDoc(r.document));
  }

  /** Belge son okunduğundan beri değişmediyse günceller; değiştiyse `false` döner. */
  async claimCampaign(id, updateTime, fields) {
    try {
      await this.commit([{
        update: { name: this.name(`notificationCampaigns/${id}`), fields: encodeFields(fields) },
        updateMask: { fieldPaths: Object.keys(fields) },
        currentDocument: { updateTime },
      }]);
      return true;
    } catch (e) {
      if (e instanceof PreconditionFailed) return false;
      throw e;
    }
  }

  async updateCampaign(id, fields) {
    await this.commit([{
      update: { name: this.name(`notificationCampaigns/${id}`), fields: encodeFields(fields) },
      updateMask: { fieldPaths: Object.keys(fields) },
      currentDocument: { exists: true },
    }]);
  }

  async createCampaign(id, data) {
    await this.commit([{
      update: { name: this.name(`notificationCampaigns/${id}`), fields: encodeFields(data) },
      currentDocument: { exists: false },
    }]);
  }

  // ---- Kullanıcılar

  async listUsers() {
    const mask = ["fcmTokens", "pushEnabled", "language", "disabled"]
      .map((f) => `mask.fieldPaths=${f}`).join("&");
    const users = [];
    let pageToken = "";
    do {
      const page = await this.request(
        `${this.base}/users?pageSize=300&${mask}${pageToken ? `&pageToken=${encodeURIComponent(pageToken)}` : ""}`,
      );
      for (const d of page?.documents || []) {
        const doc = toDoc(d);
        users.push({ uid: doc.id, data: doc.data });
      }
      pageToken = page?.nextPageToken || "";
    } while (pageToken);
    return users;
  }

  /** Geçersiz cihaz anahtarlarını tek yığında kullanıcı belgelerinden çıkarır. */
  async removeTokens(removals) {
    if (!removals.length) return;
    const byUid = new Map();
    for (const { uid, token } of removals) {
      if (!byUid.has(uid)) byUid.set(uid, []);
      byUid.get(uid).push(token);
    }
    await this.commit([...byUid].map(([uid, tokens]) => ({
      transform: {
        document: this.name(`users/${uid}`),
        fieldTransforms: [{
          fieldPath: "fcmTokens",
          removeAllFromArray: { values: tokens.map((t) => ({ stringValue: t })) },
        }],
      },
    })));
  }

  // ---- Günlük hatırlatma ayarı

  getReminderConfig() {
    return this.getDoc("appConfig/dailyReminder");
  }

  /** Gönderim gün ve saatini yalnızca belge değişmediyse yazar (çift gönderimi önler). */
  async markReminderSent(updateTime, date, time) {
    try {
      await this.commit([{
        update: {
          name: this.name("appConfig/dailyReminder"),
          fields: encodeFields({ lastSentDate: date, lastSentTime: time }),
        },
        updateMask: { fieldPaths: ["lastSentDate", "lastSentTime"] },
        currentDocument: { updateTime },
      }]);
      return true;
    } catch (e) {
      if (e instanceof PreconditionFailed) return false;
      throw e;
    }
  }
}
