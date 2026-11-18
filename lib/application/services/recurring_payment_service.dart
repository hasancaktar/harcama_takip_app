import 'package:flutter/foundation.dart';

import '../../core/utils/statement_calculator.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/recurring_payment.dart';
import '../../domain/repositories/i_recurring_payment_repository.dart';

/// Otomatik (her ay tekrarlanan) ödemelerin aylık harcamalarını yönetir.
///
/// Kural: bir ayın kaydı o ay geldiğinde yazılır (bu ay dahil, gelecek aylar
/// hariç). Sonlandırmada geçmiş kayıtlar kalır; tarihi henüz gelmemiş kayıtlar
/// silinir. Düzenlemede yeni değerler tarihi henüz gelmemiş kayıtlara ve
/// sonraki aylara uygulanır.
class RecurringPaymentService {
  final IRecurringPaymentRepository _repository;

  RecurringPaymentService(this._repository);

  /// [payment] için [month] ayının harcaması.
  static Expense buildPosting(
    RecurringPayment payment,
    String month, {
    required String actorUid,
    required DateTime now,
  }) {
    final date = payment.occurrenceDate(month);
    final cutoff = payment.cardCutoffDay;
    return Expense(
      id: RecurringPayment.expenseIdFor(payment.id, month),
      teamId: payment.teamId,
      ownerUid: payment.ownerUid,
      visibility: payment.visibility,
      title: payment.title,
      amountInCents: payment.amountInCents,
      currency: payment.currency,
      category: payment.category,
      date: date,
      // Karttan ödenen otomatik ödeme o kartın ekstresine yazılır.
      paymentMethod: payment.hasCard ? 'credit_card' : 'auto_payment',
      cardId: payment.cardId,
      cardLast4: payment.cardLast4,
      recurringPaymentId: payment.id,
      statementPeriod: payment.hasCard && cutoff != null
          ? StatementCalculator.resolveStatementPeriod(date, cutoff)
          : StatementCalculator.periodOf(date),
      notes: payment.notes,
      createdBy: actorUid,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Yeni ödemeyi kaydeder ve başlangıç ayından bu aya kadarki kayıtları yazar.
  Future<RecurringPayment> create(
    RecurringPayment payment, {
    required String actorUid,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final months = payment.dueMonths(at);
    final saved = months.isEmpty
        ? payment
        : payment.copyWith(lastPostedMonth: months.last);
    await _repository.save(
      saved,
      postings: [
        for (final m in months)
          buildPosting(saved, m, actorUid: actorUid, now: at),
      ],
      actorUid: actorUid,
    );
    return saved;
  }

  /// Ödemeyi günceller. Yazılmış ama tarihi henüz gelmemiş kayıtlar yeni
  /// değerlerle yeniden yazılır; geçmiş kayıtlara dokunulmaz.
  Future<void> update(
    RecurringPayment previous,
    RecurringPayment updated, {
    required String actorUid,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final rewrite = previous.postedMonthsAfter(at);
    await _repository.save(
      updated.copyWith(updatedAt: at),
      // Henüz gerçekleşmemiş kayıtlar (yeni gün bugünden önceye düşse bile)
      // yeni değerlerle yeniden yazılır.
      postings: [
        for (final m in rewrite)
          buildPosting(updated, m, actorUid: actorUid, now: at),
      ],
      actorUid: actorUid,
    );
  }

  /// Ödemeyi sonlandırır: geçmiş kayıtlar kalır, tarihi henüz gelmemiş
  /// kayıtlar silinir ve yeni ay eklenmez.
  Future<void> cancel(
    RecurringPayment payment, {
    required String actorUid,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    await _repository.save(
      payment.copyWith(status: 'cancelled', endDate: at, updatedAt: at),
      deleteExpenseIds: [
        for (final m in payment.postedMonthsAfter(at))
          RecurringPayment.expenseIdFor(payment.id, m),
      ],
      actorUid: actorUid,
    );
  }

  /// Kullanıcının kendi aktif ödemelerinde eksik ayları yazar (uygulama
  /// açılışında). Yazılan kayıt sayısını döner; hata olursa 0.
  Future<int> syncOwn(String uid, {DateTime? now}) async {
    final at = now ?? DateTime.now();
    var posted = 0;
    try {
      for (final payment in await _repository.getActiveOwn(uid)) {
        final months = payment.dueMonths(at);
        if (months.isEmpty) continue;
        await _repository.save(
          payment.copyWith(lastPostedMonth: months.last),
          postings: [
            for (final m in months)
              buildPosting(payment, m, actorUid: uid, now: at),
          ],
          actorUid: uid,
        );
        posted += months.length;
      }
    } catch (e) {
      debugPrint('[RecurringPayment] Eşitleme hatası: $e');
    }
    return posted;
  }
}
