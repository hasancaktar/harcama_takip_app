"use strict";

/**
 * Yönetim paneli bildirimleri için saf mantık (birim testleri: test/notifications.test.js).
 */

const ADMIN_EMAIL = "hasancaktar@gmail.com";
const TIME_ZONE = "Europe/Istanbul";
/** Zamanlayıcı her 5 dakikada bir çalışır; kaçan çalıştırmalar için tolerans. */
const SEND_WINDOW_MINUTES = 30;

function isAdminUser(userRecord) {
  return !!userRecord &&
    userRecord.emailVerified === true &&
    String(userRecord.email || "").toLowerCase() === ADMIN_EMAIL;
}

/** Belirtilen saat dilimindeki yerel tarih ve gün içi dakika. */
function localClock(date, timeZone = TIME_ZONE) {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone, year: "numeric", month: "2-digit", day: "2-digit",
    hour: "2-digit", minute: "2-digit", hourCycle: "h23",
  }).formatToParts(date);
  const get = (type) => parts.find((p) => p.type === type).value;
  return {
    date: `${get("year")}-${get("month")}-${get("day")}`,
    minutes: Number(get("hour")) * 60 + Number(get("minute")),
  };
}

/**
 * Günlük hatırlatma şimdi gönderilmeli mi?
 * - Ayar kapalıysa gönderilmez.
 * - Aynı yerel günde yalnızca bir kez gönderilir (lastSentDate).
 * - Ayarlanan saatten sonraki SEND_WINDOW_MINUTES dakika içinde gönderilir; böylece
 *   zamanlayıcı gecikse de bildirim kaçmaz, saatler sonra da gönderilmez.
 *   Saat dilimi kuralları (yaz saati vb.) Intl tarafından hesaplanır.
 */
function shouldSendDailyReminder(config, now = new Date()) {
  if (!config || config.enabled !== true) return false;
  const clock = localClock(now, config.timezone || TIME_ZONE);
  if (config.lastSentDate === clock.date) return false;
  const target = Number(config.hour) * 60 + Number(config.minute);
  if (!Number.isFinite(target)) return false;
  const diff = clock.minutes - target;
  return diff >= 0 && diff < SEND_WINDOW_MINUTES;
}

/**
 * Alıcıları seçer ve dile göre gruplar.
 * Kullanıcı tercihleri dikkate alınır:
 *  - pushEnabled === false olanlara gönderilmez,
 *  - günlük hatırlatmada, kendi yerel hatırlatıcısını açmış kullanıcılar atlanır (çift bildirim olmasın).
 * @param {Array<{uid: string, data: object}>} users
 * @return {{groups: {tr: Array, en: Array}, recipientCount: number, optedOutCount: number, tokenCount: number}}
 */
function selectRecipients(users, { target = "all", targetUids = [], type = "manual" } = {}) {
  const selected = new Set(targetUids);
  const groups = { tr: [], en: [] };
  let recipientCount = 0;
  let optedOutCount = 0;
  let tokenCount = 0;

  for (const user of users) {
    if (target === "selected" && !selected.has(user.uid)) continue;
    const data = user.data || {};
    const tokens = Array.isArray(data.fcmTokens) ? data.fcmTokens.filter((t) => typeof t === "string" && t) : [];
    if (data.pushEnabled === false || (type === "daily" && data.dailyReminderEnabled === true)) {
      optedOutCount++;
      continue;
    }
    if (tokens.length === 0) continue;
    recipientCount++;
    tokenCount += tokens.length;
    const lang = data.language === "en" ? "en" : "tr";
    for (const token of tokens) groups[lang].push({ token, uid: user.uid });
  }
  return { groups, recipientCount, optedOutCount, tokenCount };
}

/** Dile göre başlık/metin; İngilizce boşsa Türkçe kullanılır. */
function messageFor(lang, content) {
  const title = lang === "en" && content.titleEn ? content.titleEn : content.titleTr;
  const body = lang === "en" && content.bodyEn ? content.bodyEn : content.bodyTr;
  return { title: String(title || "").slice(0, 80), body: String(body || "").slice(0, 240) };
}

function resultStatus({ tokenCount, successCount, failureCount }) {
  if (tokenCount === 0) return "no_recipients";
  if (failureCount === 0) return "sent";
  return successCount > 0 ? "partial" : "failed";
}

function chunk(list, size) {
  const out = [];
  for (let i = 0; i < list.length; i += size) out.push(list.slice(i, i + size));
  return out;
}

module.exports = {
  ADMIN_EMAIL, TIME_ZONE, SEND_WINDOW_MINUTES,
  isAdminUser, localClock, shouldSendDailyReminder, selectRecipients, messageFor, resultStatus, chunk,
};
