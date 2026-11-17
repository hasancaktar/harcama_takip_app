"use strict";

/**
 * Harcama Takip — Cloud Functions (2. nesil)
 *
 * 1. postDueInstallments: Her gece vadesi gelen taksitleri idempotent olarak harcamalara işler.
 *    (İstemci de uygulama açılışında aynı işlemi yapar; fonksiyon, uygulama hiç açılmasa da
 *    ekstrelerin güncel kalmasını sağlar.)
 * 2. notifyTeamOnExpense: Takım harcaması eklendiğinde diğer üyelere FCM bildirimi gönderir.
 * 3. sendCampaign: Yöneticinin kuyruğa eklediği bildirimi gönderir ve sonucu kaydeder.
 * 4. sendDailyReminder: Yöneticinin ayarladığı saatte günlük hatırlatmayı gönderir.
 *
 * Not: Önceki sürümdeki HTTP API ("dev-secret-key" yedek anahtarıyla herkese açık bir uç nokta)
 * ve hiçbir iş yapmadan saat başı çalışan hatırlatıcı fonksiyonu güvenlik ve maliyet nedeniyle kaldırıldı.
 */

const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { getAuth } = require("firebase-admin/auth");
const { setGlobalOptions } = require("firebase-functions/v2");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const { applyDuePostings } = require("./lib/installments");
const notifications = require("./lib/notifications");

initializeApp();
setGlobalOptions({ region: "europe-west1", maxInstances: 5 });

const db = getFirestore();

exports.postDueInstallments = onSchedule(
  { schedule: "10 0 * * *", timeZone: "Europe/Istanbul", retryCount: 1 },
  async () => {
    const plans = await db.collection("installmentPlans").where("status", "==", "active").get();
    let posted = 0;

    for (const planDoc of plans.docs) {
      try {
        posted += await db.runTransaction(async (tx) => {
          const fresh = await tx.get(planDoc.ref);
          if (!fresh.exists) return 0;
          const result = applyDuePostings(planDoc.id, fresh.data(), new Date());
          if (result.postings.length === 0) {
            // Taksitler baştan yazılmış olabilir; son taksit yansıdıysa planı kapat.
            if (result.status !== fresh.data().status) {
              tx.update(planDoc.ref, { status: result.status, updatedAt: new Date().toISOString() });
            }
            return 0;
          }

          // Firestore işlemlerinde tüm okumalar yazmalardan önce yapılmalıdır.
          const refs = result.postings.map((p) => db.collection("expenses").doc(p.id));
          const existing = await Promise.all(refs.map((ref) => tx.get(ref)));
          let created = 0;
          existing.forEach((snap, i) => {
            if (!snap.exists) {
              tx.set(refs[i], result.postings[i].data);
              created++;
            }
          });
          tx.update(planDoc.ref, {
            installmentSchedule: result.schedule,
            status: result.status,
            updatedAt: new Date().toISOString(),
          });
          return created;
        });
      } catch (error) {
        logger.error("Taksit planı işlenemedi", { planId: planDoc.id, error: error.message });
      }
    }
    logger.info("Taksit işleme tamamlandı", { plans: plans.size, posted });
  },
);

exports.notifyTeamOnExpense = onDocumentCreated("expenses/{expenseId}", async (event) => {
  const expense = event.data && event.data.data();
  if (!expense || expense.visibility !== "team" || !expense.teamId || expense.status !== "active") return;
  // Sistem tarafından işlenen aylık taksitler için bildirim gönderme (gürültü yaratır).
  if (expense.createdBy === "system") return;

  const teamSnap = await db.collection("teams").doc(expense.teamId).get();
  if (!teamSnap.exists) return;
  const team = teamSnap.data();
  const recipients = (team.memberUids || []).filter((uid) => uid !== expense.ownerUid);
  if (recipients.length === 0) return;

  const userSnaps = await db.getAll(...recipients.map((uid) => db.collection("users").doc(uid)));
  const tokenOwners = new Map();
  for (const snap of userSnaps) {
    for (const token of snap.get("fcmTokens") || []) tokenOwners.set(token, snap.id);
  }
  const tokens = [...tokenOwners.keys()];
  if (tokens.length === 0) return;

  const amount = new Intl.NumberFormat("tr-TR", { style: "currency", currency: expense.currency || "TRY" })
    .format((expense.amountInCents || 0) / 100);

  const response = await getMessaging().sendEachForMulticast({
    tokens,
    notification: {
      title: `${team.name}: yeni harcama`,
      body: `${expense.title} · ${amount}`,
    },
    data: { route: `/expenses/${event.params.expenseId}` },
    android: { notification: { channelId: "team_expenses" } },
  });

  // Geçersiz cihaz anahtarlarını temizle.
  const cleanup = [];
  response.responses.forEach((res, i) => {
    const code = res.error && res.error.code;
    if (code === "messaging/registration-token-not-registered" || code === "messaging/invalid-registration-token") {
      const uid = tokenOwners.get(tokens[i]);
      cleanup.push(db.collection("users").doc(uid).update({ fcmTokens: FieldValue.arrayRemove(tokens[i]) }));
    }
  });
  await Promise.allSettled(cleanup);
  logger.info("Takım bildirimi gönderildi", { success: response.successCount, failure: response.failureCount });
});

/**
 * Bir bildirimi alıcılara gönderir, geçersiz cihaz anahtarlarını temizler ve
 * sonucu kampanya belgesine yazar.
 */
async function deliverCampaign(campaignRef, campaign) {
  await campaignRef.update({ status: "sending" });
  try {
    const usersSnap = await db.collection("users").get();
    const users = usersSnap.docs.map((d) => ({ uid: d.id, data: d.data() }));
    const selection = notifications.selectRecipients(users, {
      target: campaign.target,
      targetUids: campaign.targetUids || [],
      type: campaign.type,
    });

    let successCount = 0;
    let failureCount = 0;
    const cleanup = [];
    for (const lang of ["tr", "en"]) {
      const message = notifications.messageFor(lang, campaign);
      for (const batch of notifications.chunk(selection.groups[lang], 500)) {
        const response = await getMessaging().sendEachForMulticast({
          tokens: batch.map((b) => b.token),
          notification: message,
          data: { route: "/expenses/new", campaignId: campaignRef.id },
          android: { notification: { channelId: "announcements" } },
        });
        successCount += response.successCount;
        failureCount += response.failureCount;
        response.responses.forEach((res, i) => {
          const code = res.error && res.error.code;
          if (code === "messaging/registration-token-not-registered" ||
              code === "messaging/invalid-registration-token") {
            cleanup.push(db.collection("users").doc(batch[i].uid)
              .update({ fcmTokens: FieldValue.arrayRemove(batch[i].token) }));
          }
        });
      }
    }
    await Promise.allSettled(cleanup);

    await campaignRef.update({
      status: notifications.resultStatus({ tokenCount: selection.tokenCount, successCount, failureCount }),
      recipientCount: selection.recipientCount,
      optedOutCount: selection.optedOutCount,
      tokenCount: selection.tokenCount,
      successCount,
      failureCount,
      finishedAt: FieldValue.serverTimestamp(),
    });
    logger.info("Bildirim gönderildi", { id: campaignRef.id, successCount, failureCount });
  } catch (error) {
    logger.error("Bildirim gönderilemedi", { id: campaignRef.id, error: error.message });
    await campaignRef.update({
      status: "failed",
      error: String(error.message || error).slice(0, 300),
      finishedAt: FieldValue.serverTimestamp(),
    });
  }
}

exports.sendCampaign = onDocumentCreated("notificationCampaigns/{campaignId}", async (event) => {
  const campaign = event.data && event.data.data();
  if (!campaign || campaign.status !== "queued" || campaign.type !== "manual") return;

  // Savunma derinliği: Firestore kuralları zaten yalnızca yöneticiye izin verir;
  // gönderen burada Auth kaydından ikinci kez doğrulanır.
  let author = null;
  try {
    author = await getAuth().getUser(String(campaign.createdBy || ""));
  } catch (_) {
    author = null;
  }
  if (!notifications.isAdminUser(author)) {
    logger.warn("Yetkisiz bildirim isteği reddedildi", { id: event.params.campaignId });
    await event.data.ref.update({
      status: "failed", error: "unauthorized", finishedAt: FieldValue.serverTimestamp(),
    });
    return;
  }
  await deliverCampaign(event.data.ref, campaign);
});

exports.sendDailyReminder = onSchedule(
  { schedule: "every 5 minutes", timeZone: notifications.TIME_ZONE, retryCount: 0 },
  async () => {
    const configRef = db.collection("appConfig").doc("dailyReminder");
    const now = new Date();

    // İşlem (transaction) ile "bugün gönderildi" işareti atomik konur: aynı anda
    // çalışan iki örnek veya yeniden deneme çift bildirim gönderemez.
    const config = await db.runTransaction(async (tx) => {
      const snap = await tx.get(configRef);
      const data = snap.exists ? snap.data() : null;
      if (!notifications.shouldSendDailyReminder(data, now)) return null;
      tx.update(configRef, {
        lastSentDate: notifications.localClock(now, data.timezone || notifications.TIME_ZONE).date,
        lastSentTime: notifications.reminderTime(data),
      });
      return data;
    });
    if (!config) return;

    const campaignRef = db.collection("notificationCampaigns").doc();
    const campaign = {
      id: campaignRef.id,
      type: "daily",
      titleTr: config.titleTr,
      bodyTr: config.bodyTr,
      titleEn: config.titleEn || "",
      bodyEn: config.bodyEn || "",
      target: config.target || "all",
      targetUids: config.targetUids || [],
      status: "queued",
      createdBy: "system",
      createdByEmail: "Otomatik",
      createdAt: FieldValue.serverTimestamp(),
    };
    await campaignRef.set(campaign);
    await deliverCampaign(campaignRef, campaign);
  },
);
