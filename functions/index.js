"use strict";

/**
 * Harcama Takip — Cloud Functions (2. nesil)
 *
 * 1. postDueInstallments: Her gece vadesi gelen taksitleri idempotent olarak harcamalara işler.
 *    (İstemci de uygulama açılışında aynı işlemi yapar; fonksiyon, uygulama hiç açılmasa da
 *    ekstrelerin güncel kalmasını sağlar.)
 * 2. notifyTeamOnExpense: Takım harcaması eklendiğinde diğer üyelere FCM bildirimi gönderir.
 *
 * Not: Önceki sürümdeki HTTP API ("dev-secret-key" yedek anahtarıyla herkese açık bir uç nokta)
 * ve hiçbir iş yapmadan saat başı çalışan hatırlatıcı fonksiyonu güvenlik ve maliyet nedeniyle kaldırıldı.
 */

const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { setGlobalOptions } = require("firebase-functions/v2");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const { applyDuePostings } = require("./lib/installments");

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
          if (result.postings.length === 0) return 0;

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
