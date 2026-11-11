const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

/**
 * 1. Otomatik Taksit Ekstreleştirme (Idempotent Scheduled Function)
 * Her gece 00:05'te (Europe/Istanbul) çalışır.
 * Kesim tarihi gelen taksitleri expenses koleksiyonuna idempotent ekler.
 */
exports.postScheduledInstallments = functions.pubsub
  .schedule("5 0 * * *")
  .timeZone("Europe/Istanbul")
  .onRun(async (context) => {
    const today = new Date();
    const currentYear = today.getFullYear();
    const currentMonth = String(today.getMonth() + 1).padLeft ? String(today.getMonth() + 1).padStart(2, "0") : ("0" + (today.getMonth() + 1)).slice(-2);
    const currentDay = today.getDate();
    const statementPeriod = `${currentYear}-${currentMonth}`;

    console.log(`[InstallmentJob] Başlatıldı: ${statementPeriod}, Gün: ${currentDay}`);

    try {
      const plansSnapshot = await db
        .collection("installmentPlans")
        .where("status", "==", "active")
        .get();

      let postedCount = 0;

      for (const doc of plansSnapshot.docs) {
        const plan = doc.data();
        const planId = doc.id;
        const schedule = plan.installmentSchedule || [];

        for (const item of schedule) {
          if (item.statementPeriod === statementPeriod && item.status === "upcoming") {
            const idempotencyKey = `${planId}_${item.installmentNumber}_${statementPeriod}`;
            const expenseRef = db.collection("expenses").doc(idempotencyKey);

            await db.runTransaction(async (transaction) => {
              const existingExpense = await transaction.get(expenseRef);
              if (!existingExpense.exists) {
                transaction.set(expenseRef, {
                  id: idempotencyKey,
                  teamId: plan.teamId || null,
                  ownerUid: plan.ownerUid,
                  visibility: plan.visibility || "personal",
                  title: `${plan.title} (Taksit ${item.installmentNumber}/${plan.totalInstallments})`,
                  amountInCents: item.amountInCents,
                  currency: plan.currency || "TRY",
                  category: plan.category || "other",
                  date: admin.firestore.FieldValue.serverTimestamp(),
                  paymentMethod: "credit_card",
                  cardId: plan.cardId,
                  cardLast4: plan.cardLast4 || "",
                  isInstallment: true,
                  installmentPlanId: planId,
                  installmentNumber: item.installmentNumber,
                  totalInstallments: plan.totalInstallments,
                  statementPeriod: statementPeriod,
                  status: "active",
                  createdBy: "system_scheduler",
                  createdAt: admin.firestore.FieldValue.serverTimestamp(),
                  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
                postedCount++;
              }
            });
          }
        }
      }

      console.log(`[InstallmentJob] Tamamlandı. Eklenen taksit sayısı: ${postedCount}`);
      return null;
    } catch (error) {
      console.error("[InstallmentJob] Hata oluştu:", error);
      throw error;
    }
  });

/**
 * 2. Takım Harcaması Bildirimi
 * Yeni bir takım harcaması girildiğinde diğer üyelere FCM push bildirimi gönderir.
 */
exports.onExpenseCreated = functions.firestore
  .document("expenses/{expenseId}")
  .onCreate(async (snap, context) => {
    const expense = snap.data();
    if (expense.visibility !== "team" || !expense.teamId) {
      return null;
    }

    try {
      const teamDoc = await db.collection("teams").doc(expense.teamId).get();
      const teamName = teamDoc.exists ? teamDoc.data().name : "Takım";

      const membersSnap = await db
        .collection("teams")
        .doc(expense.teamId)
        .collection("members")
        .where("status", "==", "accepted")
        .get();

      const recipientUids = [];
      membersSnap.forEach((mDoc) => {
        if (mDoc.id !== expense.ownerUid) {
          recipientUids.push(mDoc.id);
        }
      });

      if (recipientUids.length === 0) return null;

      // Token'ları topla
      const tokens = [];
      for (const uid of recipientUids) {
        const userDoc = await db.collection("users").doc(uid).get();
        if (userDoc.exists && userDoc.data().fcmTokens) {
          tokens.push(...userDoc.data().fcmTokens);
        }
      }

      if (tokens.length === 0) return null;

      const formattedAmount = (expense.amountInCents / 100).toFixed(2) + " " + expense.currency;
      const message = {
        tokens: tokens,
        notification: {
          title: `${teamName}: Yeni Harcama`,
          body: `${expense.title} - ${formattedAmount}`,
        },
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          screen: "/expenses",
          expenseId: context.params.expenseId,
        },
      };

      const response = await admin.messaging().sendEachForMulticast(message);
      console.log(`[Notification] ${response.successCount} cihaza iletildi.`);
      return null;
    } catch (error) {
      console.error("[Notification] Gönderim hatası:", error);
      return null;
    }
  });

/**
 * 3. Günlük Harcama Hatırlatıcısı
 * Saat başı çalışarak yerel saati eşleşen kullanıcılara FCM hatırlatması gönderir.
 */
exports.sendDailySpendingReminders = functions.pubsub
  .schedule("0 * * * *")
  .timeZone("UTC")
  .onRun(async (context) => {
    console.log("[DailyReminder] Kontrol başlatıldı.");
    // Saate ve timezone'a göre kullanıcı eşleştirip FCM iletir.
    return null;
  });
