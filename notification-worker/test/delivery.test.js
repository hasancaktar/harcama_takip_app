import { test } from "node:test";
import assert from "node:assert/strict";
import { maybeQueueDailyReminder, processCampaign, runScheduled } from "../src/delivery.js";
import { MemoryStore, fakeSender, user } from "./helpers.js";

const manual = (overrides = {}) => ({
  id: "c1",
  type: "manual",
  titleTr: "Duyuru",
  bodyTr: "Merhaba",
  titleEn: "Notice",
  bodyEn: "Hello",
  target: "all",
  targetUids: [],
  status: "queued",
  createdBy: "admin-uid",
  createdAt: new Date("2026-11-18T10:00:00Z"),
  ...overrides,
});

const now = new Date("2026-11-18T10:00:30Z");

test("tüm kullanıcılara: dil tercihine göre gönderir, bildirimi kapatanı atlar", async () => {
  const store = new MemoryStore({
    users: [
      user("a", ["ta1", "ta2"]),
      user("b", ["tb"], { language: "en" }),
      user("c", ["tc"], { pushEnabled: false }),
      user("d", []),
    ],
    campaigns: { c1: manual() },
  });
  const { send, sent } = fakeSender();
  const result = await processCampaign({ store, send, campaign: await store.getCampaign("c1"), now });

  assert.equal(result.status, "sent");
  assert.deepEqual(sent.map((m) => [m.token, m.title]), [["ta1", "Duyuru"], ["ta2", "Duyuru"], ["tb", "Notice"]]);
  assert.deepEqual(sent[0].data, { route: "/expenses/new", campaignId: "c1" });
  const c = store.campaign("c1");
  assert.equal(c.status, "sent");
  assert.equal(c.recipientCount, 2);
  assert.equal(c.tokenCount, 3);
  assert.equal(c.successCount, 3);
  assert.equal(c.failureCount, 0);
  assert.equal(c.optedOutCount, 1);
  assert.equal(c.leaseUntil, null);
  assert.ok(c.finishedAt instanceof Date);
});

test("seçili kullanıcılar: yalnızca seçilenlere gider", async () => {
  const store = new MemoryStore({
    users: [user("a", ["ta"]), user("b", ["tb"])],
    campaigns: { c1: manual({ target: "selected", targetUids: ["b"] }) },
  });
  const { send, sent } = fakeSender();
  await processCampaign({ store, send, campaign: await store.getCampaign("c1"), now });
  assert.deepEqual(sent.map((m) => m.token), ["tb"]);
});

test("geçersiz cihaz anahtarı silinir; kısmi başarı 'partial' olur", async () => {
  const store = new MemoryStore({
    users: [user("a", ["good", "dead"]), user("b", ["flaky"])],
    campaigns: { c1: manual() },
  });
  const { send } = fakeSender({ bad: ["dead"], failing: ["flaky"] });
  await processCampaign({ store, send, campaign: await store.getCampaign("c1"), now });

  assert.deepEqual(store.removed, [{ uid: "a", token: "dead" }]);
  assert.deepEqual(store.users[0].data.fcmTokens, ["good"]);
  const c = store.campaign("c1");
  assert.equal(c.status, "partial");
  assert.equal(c.successCount, 1);
  assert.equal(c.failureCount, 2);
});

test("alıcı yoksa 'no_recipients'", async () => {
  const store = new MemoryStore({ users: [user("a", [])], campaigns: { c1: manual() } });
  const { send } = fakeSender();
  const r = await processCampaign({ store, send, campaign: await store.getCampaign("c1"), now });
  assert.equal(r.status, "no_recipients");
});

test("büyük gönderim parçalara bölünür ve kaldığı yerden sürer", async () => {
  const store = new MemoryStore({
    users: [user("a", ["t1", "t2"]), user("b", ["t3", "t4"]), user("c", ["t5"])],
    campaigns: { c1: manual() },
  });
  const { send, sent } = fakeSender();

  const first = await processCampaign({ store, send, campaign: await store.getCampaign("c1"), now, chunkSize: 2 });
  assert.equal(first.status, "sending");
  assert.equal(store.campaign("c1").cursor, 2);
  assert.equal(store.campaign("c1").status, "sending");

  await processCampaign({ store, send, campaign: await store.getCampaign("c1"), now, chunkSize: 2 });
  const last = await processCampaign({ store, send, campaign: await store.getCampaign("c1"), now, chunkSize: 2 });
  assert.equal(last.status, "sent");
  assert.deepEqual(sent.map((m) => m.token), ["t1", "t2", "t3", "t4", "t5"]);
  assert.equal(store.campaign("c1").successCount, 5);
});

test("aynı kampanya aynı anda iki kez işlenmez", async () => {
  const store = new MemoryStore({ users: [user("a", ["t1"])], campaigns: { c1: manual() } });
  const { send, sent } = fakeSender();
  const snapshot = await store.getCampaign("c1");
  const [a, b] = await Promise.all([
    processCampaign({ store, send, campaign: snapshot, now }),
    processCampaign({ store, send, campaign: snapshot, now }),
  ]);
  assert.deepEqual([a.status, b.status].sort(), ["busy", "sent"]);
  assert.equal(sent.length, 1);
});

test("başka bir çalıştırmanın kilidi sürerken beklenir; kilit dolunca devralınır", async () => {
  const store = new MemoryStore({
    users: [user("a", ["t1"])],
    campaigns: { c1: manual({ status: "sending", leaseUntil: new Date(now.getTime() + 60_000) }) },
  });
  const { send } = fakeSender();
  assert.equal((await processCampaign({ store, send, campaign: await store.getCampaign("c1"), now })).status, "busy");
  const later = new Date(now.getTime() + 3 * 60_000);
  assert.equal((await processCampaign({ store, send, campaign: await store.getCampaign("c1"), now: later })).status, "sent");
});

test("gönderilmiş kampanya tekrar işlenmez", async () => {
  const store = new MemoryStore({ users: [user("a", ["t1"])], campaigns: { c1: manual({ status: "sent" }) } });
  const { send, sent } = fakeSender();
  assert.equal((await processCampaign({ store, send, campaign: await store.getCampaign("c1"), now })).status, "skipped");
  assert.equal(sent.length, 0);
});

test("beklenmeyen hata kampanyayı 'failed' yapar", async () => {
  const store = new MemoryStore({ campaigns: { c1: manual() } });
  store.listUsers = async () => { throw new Error("Firestore 503"); };
  const { send } = fakeSender();
  const r = await processCampaign({ store, send, campaign: await store.getCampaign("c1"), now });
  assert.equal(r.status, "failed");
  assert.equal(store.campaign("c1").status, "failed");
  assert.match(store.campaign("c1").error, /503/);
});

// ---------------------------------------------------------------- Günlük hatırlatma

const reminder = (overrides = {}) => ({
  enabled: true,
  hour: 21,
  minute: 0,
  titleTr: "Harcama Takip",
  bodyTr: "Bugünkü harcamalarınızı girmeyi unutmayın!",
  titleEn: "Harcama Takip",
  bodyEn: "Don't forget to log today's expenses!",
  target: "all",
  targetUids: [],
  timezone: "Europe/Istanbul",
  ...overrides,
});

// 21:02 İstanbul = 18:02 UTC
const at2102 = new Date("2026-11-18T18:02:00Z");

test("günlük hatırlatma saatinde bir kez kuyruğa eklenir ve gönderilir", async () => {
  const store = new MemoryStore({
    users: [user("a", ["ta"]), user("b", ["tb"], { dailyReminderEnabled: true })],
    reminder: reminder(),
  });
  const { send, sent } = fakeSender();
  let n = 0;
  const newId = () => `d${++n}`;

  const first = await runScheduled({ store, send, now: at2102, newId });
  assert.equal(first.queuedDaily, "d1");
  assert.equal(first.processed, "d1");
  assert.equal(store.campaign("d1").type, "daily");
  assert.equal(store.campaign("d1").status, "sent");
  // Kişisel hatırlatıcısı açık olan kullanıcıya da gider.
  assert.deepEqual(sent.map((m) => m.token), ["ta", "tb"]);
  assert.equal(store.reminder.data.lastSentDate, "2026-11-18");
  assert.equal(store.reminder.data.lastSentTime, "21:00");

  const again = await runScheduled({ store, send, now: new Date(at2102.getTime() + 60_000), newId });
  assert.equal(again.queuedDaily, null);
  assert.equal(sent.length, 2);
});

test("yönetici saati değiştirirse aynı gün yeni saatte tekrar gönderilir", async () => {
  const store = new MemoryStore({
    users: [user("a", ["ta"])],
    reminder: reminder({ hour: 21, minute: 30, lastSentDate: "2026-11-18", lastSentTime: "21:00" }),
  });
  const { send, sent } = fakeSender();
  // 21:31 İstanbul
  const r = await runScheduled({ store, send, now: new Date("2026-11-18T18:31:00Z"), newId: () => "d2" });
  assert.equal(r.queuedDaily, "d2");
  assert.equal(sent.length, 1);
  assert.equal(store.reminder.data.lastSentTime, "21:30");
});

test("hatırlatma kapalıyken veya saati gelmemişken gönderilmez", async () => {
  const off = new MemoryStore({ reminder: reminder({ enabled: false }) });
  assert.equal(await maybeQueueDailyReminder({ store: off, now: at2102 }), null);
  const early = new MemoryStore({ reminder: reminder() });
  assert.equal(await maybeQueueDailyReminder({ store: early, now: new Date("2026-11-18T17:30:00Z") }), null);
  const none = new MemoryStore();
  assert.equal(await maybeQueueDailyReminder({ store: none, now: at2102 }), null);
});

test("iki çalıştırma aynı anda denerse hatırlatma yalnızca bir kez oluşturulur", async () => {
  const store = new MemoryStore({ reminder: reminder() });
  const ids = await Promise.all([
    maybeQueueDailyReminder({ store, now: at2102, newId: () => "x" }),
    maybeQueueDailyReminder({ store, now: at2102, newId: () => "y" }),
  ]);
  assert.equal(ids.filter(Boolean).length, 1);
  assert.equal(store.campaigns.size, 1);
});

test("zamanlayıcı bekleyen en eski kampanyayı işler", async () => {
  const store = new MemoryStore({
    users: [user("a", ["ta"])],
    campaigns: {
      newer: manual({ id: "newer", createdAt: new Date("2026-11-18T10:05:00Z") }),
      older: manual({ id: "older", createdAt: new Date("2026-11-18T10:01:00Z") }),
    },
  });
  const { send } = fakeSender();
  const r = await runScheduled({ store, send, now });
  assert.equal(r.processed, "older");
  assert.equal(store.campaign("newer").status, "queued");
});
