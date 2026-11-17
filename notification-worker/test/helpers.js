// Testler için bellek içi depo ve yardımcılar.

export class MemoryStore {
  constructor({ users = [], campaigns = {}, reminder = null } = {}) {
    this.users = users; // [{uid, data}]
    this.campaigns = new Map(Object.entries(campaigns).map(([id, data]) => [id, { data: { ...data }, version: 1 }]));
    this.reminder = reminder ? { data: { ...reminder }, version: 1 } : null;
    this.removed = [];
    this.calls = [];
  }

  #doc(id, entry) {
    return entry ? { id, data: { ...entry.data }, updateTime: `v${entry.version}` } : null;
  }

  async getCampaign(id) {
    return this.#doc(id, this.campaigns.get(id));
  }

  async findPendingCampaigns() {
    return [...this.campaigns]
      .filter(([, e]) => e.data.status === "queued" || e.data.status === "sending")
      .map(([id, e]) => this.#doc(id, e));
  }

  async claimCampaign(id, updateTime, fields) {
    const e = this.campaigns.get(id);
    if (!e || `v${e.version}` !== updateTime) return false;
    Object.assign(e.data, fields);
    e.version++;
    return true;
  }

  async updateCampaign(id, fields) {
    const e = this.campaigns.get(id);
    Object.assign(e.data, fields);
    e.version++;
  }

  async createCampaign(id, data) {
    if (this.campaigns.has(id)) throw new Error("exists");
    this.campaigns.set(id, { data: { ...data }, version: 1 });
  }

  async listUsers() {
    this.calls.push("listUsers");
    return this.users.map((u) => ({ uid: u.uid, data: { ...u.data } }));
  }

  async removeTokens(removals) {
    this.removed.push(...removals);
    for (const { uid, token } of removals) {
      const u = this.users.find((x) => x.uid === uid);
      if (u) u.data.fcmTokens = (u.data.fcmTokens || []).filter((t) => t !== token);
    }
  }

  async getReminderConfig() {
    return this.reminder ? { id: "dailyReminder", data: { ...this.reminder.data }, updateTime: `v${this.reminder.version}` } : null;
  }

  async markReminderSent(updateTime, date) {
    if (!this.reminder || `v${this.reminder.version}` !== updateTime) return false;
    this.reminder.data.lastSentDate = date;
    this.reminder.version++;
    return true;
  }

  campaign(id) {
    return this.campaigns.get(id).data;
  }
}

/** Gönderilen mesajları kaydeden sahte FCM; `bad` içindeki anahtarlar geçersiz sayılır. */
export function fakeSender({ bad = [], failing = [] } = {}) {
  const sent = [];
  const send = async (msg) => {
    sent.push(msg);
    if (bad.includes(msg.token)) return { ok: false, unregistered: true, error: "UNREGISTERED" };
    if (failing.includes(msg.token)) return { ok: false, unregistered: false, error: "UNAVAILABLE" };
    return { ok: true, unregistered: false };
  };
  return { send, sent };
}

export const user = (uid, tokens, extra = {}) => ({ uid, data: { fcmTokens: tokens, ...extra } });
