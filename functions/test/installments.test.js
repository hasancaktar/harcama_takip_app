"use strict";
const { test } = require("node:test");
const assert = require("node:assert/strict");
const { applyDuePostings, periodOf, expenseIdFor } = require("../lib/installments");

const plan = (overrides = {}) => ({
  ownerUid: "alice",
  visibility: "personal",
  title: "Telefon",
  totalInstallments: 3,
  totalAmountInCents: 30000,
  cardId: "c1",
  cardLast4: "1234",
  category: "shopping",
  status: "active",
  startDate: "2026-10-20T12:00:00.000",
  installmentSchedule: [
    { installmentNumber: 1, amountInCents: 10000, statementPeriod: "2026-11",
      statementCutoffDate: "2026-11-15T23:59:59.999", status: "posted" },
    { installmentNumber: 2, amountInCents: 10000, statementPeriod: "2026-12",
      statementCutoffDate: "2026-12-15T23:59:59.999", status: "upcoming" },
    { installmentNumber: 3, amountInCents: 10000, statementPeriod: "2027-01",
      statementCutoffDate: "2027-01-15T23:59:59.999", status: "upcoming" },
  ],
  ...overrides,
});

test("periodOf İstanbul saatine göre dönem üretir", () => {
  // 31 Aralık 22:30 UTC = 1 Ocak 01:30 İstanbul
  assert.equal(periodOf(new Date("2026-12-31T22:30:00Z")), "2027-01");
});

test("yalnızca içinde bulunulan döneme kadarki taksitler işlenir", () => {
  const result = applyDuePostings("p1", plan(), new Date("2026-12-02T09:00:00Z"));
  assert.equal(result.postings.length, 1);
  assert.equal(result.postings[0].id, "p1_2_2026-12");
  assert.equal(result.postings[0].data.amountInCents, 10000);
  assert.equal(result.postings[0].data.date, "2026-12-15T23:59:59.999");
  assert.equal(result.schedule[1].status, "posted");
  assert.equal(result.schedule[2].status, "upcoming");
  assert.equal(result.status, "active");
});

test("son taksit işlenince plan tamamlanır", () => {
  const result = applyDuePostings("p1", plan(), new Date("2027-01-05T09:00:00Z"));
  assert.equal(result.postings.length, 2);
  assert.equal(result.status, "completed");
});

test("iptal edilmiş planda işlem yapılmaz", () => {
  const result = applyDuePostings("p1", plan({ status: "cancelled" }), new Date("2027-05-01T00:00:00Z"));
  assert.equal(result.postings.length, 0);
});

test("idempotent kimlik istemci ile aynıdır", () => {
  assert.equal(expenseIdFor("abc", { installmentNumber: 2, statementPeriod: "2026-12" }), "abc_2_2026-12");
});

test("baştan yazılmış taksitlerde plan, son taksitin dönemi gelince tamamlanır", () => {
  const allPosted = plan({
    installmentSchedule: plan().installmentSchedule.map((i) => ({ ...i, status: "posted" })),
  });
  const december = applyDuePostings("p1", allPosted, new Date("2026-12-02T09:00:00Z"));
  assert.equal(december.postings.length, 0);
  assert.equal(december.status, "active");

  const january = applyDuePostings("p1", allPosted, new Date("2027-01-05T09:00:00Z"));
  assert.equal(january.postings.length, 0);
  assert.equal(january.status, "completed");
});

test("taksit başlığı uygulamayla aynı biçimdedir", () => {
  const result = applyDuePostings("p1", plan(), new Date("2026-12-02T09:00:00Z"));
  assert.equal(result.postings[0].data.title, "Telefon - 2. Taksit");
});
