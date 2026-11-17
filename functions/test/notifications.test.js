"use strict";
const { test } = require("node:test");
const assert = require("node:assert/strict");
const n = require("../lib/notifications");

const config = (o = {}) => ({ enabled: true, hour: 21, minute: 0, timezone: "Europe/Istanbul", ...o });

test("yönetici denetimi: yalnızca doğrulanmış yönetici e-postası", () => {
  assert.equal(n.isAdminUser({ email: "HasanCaktar@gmail.com", emailVerified: true }), true);
  assert.equal(n.isAdminUser({ email: "hasancaktar@gmail.com", emailVerified: false }), false);
  assert.equal(n.isAdminUser({ email: "baskasi@gmail.com", emailVerified: true }), false);
  assert.equal(n.isAdminUser(null), false);
});

test("günlük hatırlatma İstanbul saatine göre, ayarlanan saatte gönderilir", () => {
  // 18:02 UTC = 21:02 İstanbul
  assert.equal(n.shouldSendDailyReminder(config(), new Date("2026-11-16T18:02:00Z")), true);
  // 17:55 UTC = 20:55 İstanbul (henüz erken)
  assert.equal(n.shouldSendDailyReminder(config(), new Date("2026-11-16T17:55:00Z")), false);
  // pencere dışı: 21:45
  assert.equal(n.shouldSendDailyReminder(config(), new Date("2026-11-16T18:45:00Z")), false);
});

test("aynı gün ikinci kez gönderilmez; kapalıyken gönderilmez", () => {
  const at = new Date("2026-11-16T18:05:00Z");
  assert.equal(n.shouldSendDailyReminder(config({ lastSentDate: "2026-11-16" }), at), false);
  assert.equal(n.shouldSendDailyReminder(config({ lastSentDate: "2026-11-15" }), at), true);
  assert.equal(n.shouldSendDailyReminder(config({ enabled: false }), at), false);
  assert.equal(n.shouldSendDailyReminder(null, at), false);
});

test("saat değiştirilirse aynı gün yeni saatte bir kez daha gönderilir", () => {
  const at = new Date("2026-11-16T18:05:00Z"); // 21:05 İstanbul
  // 21:00 bugün zaten gönderildi
  assert.equal(n.shouldSendDailyReminder(config({ lastSentDate: "2026-11-16", lastSentTime: "21:00" }), at), false);
  // Sabah 09:00'da gönderilmişti, yönetici saati 21:00 yaptı
  assert.equal(n.shouldSendDailyReminder(config({ lastSentDate: "2026-11-16", lastSentTime: "09:00" }), at), true);
  assert.equal(n.reminderTime({ hour: 9, minute: 5 }), "09:05");
});

test("gece yarısına yakın saat ve gün değişimi doğru hesaplanır", () => {
  // 23:50 İstanbul = 20:50 UTC; yerel tarih 16 Kasım
  const c = config({ hour: 23, minute: 50 });
  assert.equal(n.shouldSendDailyReminder(c, new Date("2026-11-16T20:52:00Z")), true);
  assert.equal(n.localClock(new Date("2026-11-16T21:30:00Z")).date, "2026-11-17");
});

test("alıcı seçimi kullanıcı tercihlerine uyar ve dile göre gruplar", () => {
  const users = [
    { uid: "a", data: { fcmTokens: ["t1", "t2"], language: "tr" } },
    { uid: "b", data: { fcmTokens: ["t3"], language: "en" } },
    { uid: "c", data: { fcmTokens: ["t4"], pushEnabled: false } },
    { uid: "d", data: { fcmTokens: [] } },
    { uid: "e", data: { fcmTokens: ["t5"], dailyReminderEnabled: true } },
  ];
  const manual = n.selectRecipients(users, { target: "all", type: "manual" });
  assert.equal(manual.recipientCount, 3);
  assert.equal(manual.optedOutCount, 1);
  assert.equal(manual.tokenCount, 4);
  assert.deepEqual(manual.groups.en.map((x) => x.token), ["t3"]);

  // Günlük hatırlatma kişisel hatırlatıcısı açık olanlara da gider; yalnızca
  // bildirimleri kapatan atlanır.
  const daily = n.selectRecipients(users, { target: "all", type: "daily" });
  assert.equal(daily.recipientCount, 3);
  assert.equal(daily.optedOutCount, 1);

  const selected = n.selectRecipients(users, { target: "selected", targetUids: ["b", "c"] });
  assert.equal(selected.recipientCount, 1);
  assert.equal(selected.optedOutCount, 1);
});

test("mesaj dili: İngilizce boşsa Türkçe kullanılır", () => {
  const content = { titleTr: "Duyuru", bodyTr: "Merhaba", titleEn: "", bodyEn: "Hello" };
  assert.deepEqual(n.messageFor("en", content), { title: "Duyuru", body: "Hello" });
  assert.deepEqual(n.messageFor("tr", content), { title: "Duyuru", body: "Merhaba" });
});

test("sonuç durumu", () => {
  assert.equal(n.resultStatus({ tokenCount: 0, successCount: 0, failureCount: 0 }), "no_recipients");
  assert.equal(n.resultStatus({ tokenCount: 3, successCount: 3, failureCount: 0 }), "sent");
  assert.equal(n.resultStatus({ tokenCount: 3, successCount: 1, failureCount: 2 }), "partial");
  assert.equal(n.resultStatus({ tokenCount: 3, successCount: 0, failureCount: 3 }), "failed");
});
