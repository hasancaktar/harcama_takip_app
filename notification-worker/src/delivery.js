// Bildirim gönderim mantığı. Depo (store) ve FCM gönderici dışarıdan verilir;
// böylece aynı kod hem Cloudflare'de hem testlerde çalışır.
//
// Cloudflare ücretsiz planında bir çalıştırmada en fazla 50 dış istek yapılabilir.
// Bu yüzden her çalıştırma en fazla `chunkSize` cihaza gönderir ve kaldığı yeri
// (`cursor`) kampanya belgesine yazar; kalanlar bir sonraki çalıştırmada
// (dakikada bir) gönderilir. `leaseUntil`, aynı kampanyanın iki çalıştırma
// tarafından aynı anda işlenmesini önler.

import notifications from "../../functions/lib/notifications.js";

export const DEFAULT_CHUNK_SIZE = 35;
const LEASE_MS = 2 * 60 * 1000;

const asDate = (v) => (v instanceof Date ? v : v ? new Date(v) : null);

/** Gönderim sırası: önce Türkçe, sonra İngilizce; her grup kullanıcı sırasıyla. */
export function flattenRecipients(selection) {
  return [
    ...selection.groups.tr.map((r) => ({ ...r, lang: "tr" })),
    ...selection.groups.en.map((r) => ({ ...r, lang: "en" })),
  ];
}

/**
 * Bir kampanyanın sıradaki parçasını gönderir.
 * @return {Promise<{status: string, sent?: number, done?: boolean}>}
 */
export async function processCampaign({ store, send, campaign, now = new Date(), chunkSize = DEFAULT_CHUNK_SIZE }) {
  const c = campaign.data;
  if (c.status !== "queued" && c.status !== "sending") return { status: "skipped" };
  const lease = asDate(c.leaseUntil);
  if (lease && lease > now) return { status: "busy" };

  const claimed = await store.claimCampaign(campaign.id, campaign.updateTime, {
    status: "sending",
    leaseUntil: new Date(now.getTime() + LEASE_MS),
    startedAt: asDate(c.startedAt) || now,
  });
  if (!claimed) return { status: "busy" };

  try {
    const users = await store.listUsers();
    const selection = notifications.selectRecipients(users, {
      target: c.target,
      targetUids: c.targetUids || [],
      type: c.type,
    });
    const recipients = flattenRecipients(selection);
    const cursor = Number(c.cursor) || 0;
    const chunk = recipients.slice(cursor, cursor + chunkSize);

    let success = 0;
    let failure = 0;
    const invalid = [];
    for (const r of chunk) {
      const message = notifications.messageFor(r.lang, c);
      const result = await send({
        token: r.token,
        title: message.title,
        body: message.body,
        data: { route: "/expenses/new", campaignId: campaign.id },
      });
      if (result.ok) success++;
      else {
        failure++;
        if (result.unregistered) invalid.push({ uid: r.uid, token: r.token });
      }
    }
    await store.removeTokens(invalid);

    const nextCursor = cursor + chunk.length;
    const done = nextCursor >= recipients.length;
    const successCount = (Number(c.successCount) || 0) + success;
    const failureCount = (Number(c.failureCount) || 0) + failure;
    const fields = {
      cursor: nextCursor,
      successCount,
      failureCount,
      recipientCount: selection.recipientCount,
      tokenCount: selection.tokenCount,
      optedOutCount: selection.optedOutCount,
      leaseUntil: null,
    };
    if (done) {
      fields.status = notifications.resultStatus({
        tokenCount: selection.tokenCount,
        successCount,
        failureCount,
      });
      fields.finishedAt = now;
    }
    await store.updateCampaign(campaign.id, fields);
    return { status: done ? fields.status : "sending", sent: chunk.length, done };
  } catch (e) {
    await store.updateCampaign(campaign.id, {
      status: "failed",
      error: String(e.message || e).slice(0, 300),
      leaseUntil: null,
      finishedAt: now,
    });
    return { status: "failed", error: String(e.message || e) };
  }
}

/**
 * Günlük hatırlatma zamanı geldiyse, bugün için bir kez kampanya oluşturur.
 * @return {Promise<string|null>} oluşturulan kampanyanın kimliği
 */
export async function maybeQueueDailyReminder({ store, now = new Date(), newId = () => crypto.randomUUID() }) {
  const config = await store.getReminderConfig();
  if (!config || !notifications.shouldSendDailyReminder(config.data, now)) return null;
  const date = notifications.localClock(now, config.data.timezone || notifications.TIME_ZONE).date;
  if (!(await store.markReminderSent(config.updateTime, date))) return null;

  const id = newId();
  const d = config.data;
  await store.createCampaign(id, {
    id,
    type: "daily",
    titleTr: d.titleTr,
    bodyTr: d.bodyTr,
    titleEn: d.titleEn || "",
    bodyEn: d.bodyEn || "",
    target: d.target || "all",
    targetUids: d.targetUids || [],
    status: "queued",
    createdBy: "system",
    createdByEmail: "Otomatik",
    createdAt: now,
  });
  return id;
}

/** Zamanlayıcı (dakikada bir): günlük hatırlatmayı kuyruğa ekler, bekleyen bir kampanyayı ilerletir. */
export async function runScheduled({ store, send, now = new Date(), chunkSize = DEFAULT_CHUNK_SIZE, newId }) {
  const queuedDaily = await maybeQueueDailyReminder({ store, now, newId });
  const pending = (await store.findPendingCampaigns(10))
    .sort((a, b) => (asDate(a.data.createdAt) || 0) - (asDate(b.data.createdAt) || 0));
  // Dış istek sınırı nedeniyle her çalıştırmada tek kampanyanın bir parçası işlenir.
  for (const campaign of pending) {
    const result = await processCampaign({ store, send, campaign, now, chunkSize });
    if (result.status !== "busy" && result.status !== "skipped") {
      return { queuedDaily, processed: campaign.id, result };
    }
  }
  return { queuedDaily, processed: null };
}
