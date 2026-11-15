"use strict";

/**
 * Taksit işleme kuralları (istemcideki InstallmentPostingPolicy ile birebir aynı).
 * Bir taksit, ait olduğu ekstre döneminin takvim ayı geldiğinde harcama olarak işlenir.
 * Harcama kimliği deterministiktir: `${planId}_${taksitNo}_${dönem}` (idempotent).
 */

/** Verilen andaki dönemi (YYYY-MM) belirtilen saat diliminde döner. */
function periodOf(date, timeZone = "Europe/Istanbul") {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
  }).formatToParts(date);
  const year = parts.find((p) => p.type === "year").value;
  const month = parts.find((p) => p.type === "month").value;
  return `${year}-${month}`;
}

function isDue(item, currentPeriod) {
  return item.status === "upcoming" && String(item.statementPeriod) <= currentPeriod;
}

function expenseIdFor(planId, item) {
  return `${planId}_${item.installmentNumber}_${item.statementPeriod}`;
}

function toIso(value, fallback) {
  if (!value) return fallback;
  if (typeof value === "string") return value;
  if (typeof value.toDate === "function") return value.toDate().toISOString();
  if (value instanceof Date) return value.toISOString();
  return fallback;
}

/**
 * Saf fonksiyon: planın vadesi gelmiş taksitlerini ve güncellenmiş takvimini hesaplar.
 * @return {{postings: Array<{id: string, data: object}>, schedule: Array<object>, status: string}}
 */
function applyDuePostings(planId, plan, now = new Date()) {
  const schedule = Array.isArray(plan.installmentSchedule) ? plan.installmentSchedule : [];
  if (plan.status !== "active") return { postings: [], schedule, status: plan.status };

  const currentPeriod = periodOf(now);
  const nowIso = now.toISOString();
  const postings = [];
  const updated = schedule.map((item) => {
    if (!isDue(item, currentPeriod)) return item;
    const id = expenseIdFor(planId, item);
    postings.push({
      id,
      data: {
        id,
        teamId: plan.teamId || null,
        ownerUid: plan.ownerUid,
        visibility: plan.visibility || "personal",
        title: `${plan.title} (${item.installmentNumber}/${plan.totalInstallments}. taksit)`,
        amountInCents: item.amountInCents,
        currency: plan.currency || "TRY",
        category: plan.category || "other",
        date: item.installmentNumber === 1 ?
          toIso(plan.startDate, nowIso) :
          toIso(item.statementCutoffDate, nowIso),
        paymentMethod: "credit_card",
        cardId: plan.cardId || null,
        cardLast4: plan.cardLast4 || null,
        isInstallment: true,
        installmentPlanId: planId,
        installmentNumber: item.installmentNumber,
        totalInstallments: plan.totalInstallments,
        statementPeriod: item.statementPeriod,
        notes: null,
        tags: [],
        status: "active",
        createdBy: "system",
        createdAt: nowIso,
        updatedAt: nowIso,
        deletedAt: null,
        deletedBy: null,
      },
    });
    return { ...item, status: "posted" };
  });

  const allPosted = updated.length > 0 && updated.every((i) => i.status === "posted");
  return { postings, schedule: updated, status: allPosted ? "completed" : plan.status };
}

module.exports = { periodOf, isDue, expenseIdFor, applyDuePostings };
