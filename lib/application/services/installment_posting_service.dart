import 'package:flutter/foundation.dart';

import '../../core/utils/statement_calculator.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/installment_plan.dart';
import '../../domain/repositories/i_installment_repository.dart';

/// Vadesi gelen taksitlerin harcama olarak işlenmesi sonucu.
class PostingResult {
  final InstallmentPlan plan;
  final List<Expense> postings;

  const PostingResult(this.plan, this.postings);

  bool get hasChanges => postings.isNotEmpty;
}

/// Taksit planlarını harcamalara dönüştüren servis.
///
/// Her taksit deterministik kimlikle (`planId_taksitNo_dönem`) yazıldığı için işlem
/// idempotenttir: aynı taksit birden çok cihazdan veya bulut fonksiyonundan
/// işlense bile tek harcama oluşur.
class InstallmentPostingService {
  final IInstallmentRepository _repository;

  InstallmentPostingService(this._repository);

  /// Saf fonksiyon: planın vadesi gelmiş taksitlerini harcamaya dönüştürür ve planı günceller.
  static PostingResult applyDuePostings(
    InstallmentPlan plan, {
    required DateTime now,
    required String actorUid,
  }) {
    if (!plan.isActive) return PostingResult(plan, const []);

    final postings = <Expense>[];
    final schedule = <StatementInstallmentScheduleItem>[];
    for (final item in plan.installmentSchedule) {
      if (InstallmentPostingPolicy.isDue(item, now)) {
        postings.add(buildPosting(plan, item, actorUid: actorUid, now: now));
        schedule.add(item.copyWith(status: 'posted'));
      } else {
        schedule.add(item);
      }
    }
    if (postings.isEmpty) return PostingResult(plan, const []);

    final allPosted = schedule.every((s) => s.isPosted);
    return PostingResult(
      plan.copyWith(
        installmentSchedule: schedule,
        status: allPosted ? 'completed' : plan.status,
        updatedAt: now,
      ),
      postings,
    );
  }

  /// Planın tüm taksitlerini harcama olarak işler; böylece gelecek ayların
  /// harcama ve rapor ekranlarında taksitler otomatik görünür.
  static PostingResult applyAllPostings(
    InstallmentPlan plan, {
    required DateTime now,
    required String actorUid,
  }) {
    if (!plan.isActive) return PostingResult(plan, const []);

    final postings = <Expense>[];
    final schedule = <StatementInstallmentScheduleItem>[];
    for (final item in plan.installmentSchedule) {
      if (item.status != 'posted') {
        postings.add(buildPosting(plan, item, actorUid: actorUid, now: now));
        schedule.add(item.copyWith(status: 'posted'));
      } else {
        schedule.add(item);
      }
    }
    if (postings.isEmpty) return PostingResult(plan, const []);

    return PostingResult(
      plan.copyWith(
        installmentSchedule: schedule,
        status: 'active',
        updatedAt: now,
      ),
      postings,
    );
  }

  static Expense buildPosting(
    InstallmentPlan plan,
    StatementInstallmentScheduleItem item, {
    required String actorUid,
    required DateTime now,
  }) {
    return Expense(
      id: InstallmentPostingPolicy.expenseIdFor(plan.id, item),
      teamId: plan.teamId,
      ownerUid: plan.ownerUid,
      visibility: plan.visibility,
      title: '${plan.title} - ${item.installmentNumber}. Taksit',
      amountInCents: item.amountInCents,
      currency: plan.currency,
      category: plan.category,
      // İlk taksit alışveriş tarihinde, sonrakiler bankanın işlediği kesim tarihinde görünür.
      date: item.installmentNumber == 1
          ? plan.startDate
          : item.statementCutoffDate,
      paymentMethod: 'credit_card',
      cardId: plan.cardId,
      cardLast4: plan.cardLast4,
      isInstallment: true,
      installmentPlanId: plan.id,
      installmentNumber: item.installmentNumber,
      totalInstallments: plan.totalInstallments,
      statementPeriod: item.statementPeriod,
      createdBy: actorUid,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Kullanıcının kendi aktif planlarındaki vadesi gelmiş taksitleri işler.
  /// İşlenen taksit sayısını döner. Hata durumunda 0 döner ve kaydı loglar.
  Future<int> syncOwnPlans(String uid, {DateTime? now}) async {
    final at = now ?? DateTime.now();
    var posted = 0;
    try {
      final plans = await _repository.getActiveOwnPlans(uid);
      for (final plan in plans) {
        final result = applyDuePostings(plan, now: at, actorUid: uid);
        if (!result.hasChanges) {
          // Taksitler baştan yazıldığı için işlenecek bir şey kalmamış olabilir;
          // son taksit de ekstreye yansıdıysa plan tamamlanır.
          if (plan.isCompletedAt(at)) {
            await _repository.savePlanWithPostings(
              plan.copyWith(status: 'completed', updatedAt: at),
              const [],
            );
          }
          continue;
        }
        await _repository.savePlanWithPostings(result.plan, result.postings);
        posted += result.postings.length;
      }
    } catch (e) {
      debugPrint('[InstallmentPosting] Senkronizasyon hatası: $e');
    }
    return posted;
  }
}
