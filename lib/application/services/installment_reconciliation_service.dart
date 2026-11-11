import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../core/utils/statement_calculator.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/installment_plan.dart';
import '../../domain/repositories/i_expense_repository.dart';
import '../../domain/repositories/i_installment_repository.dart';

class InstallmentReconciliationService {
  final FirebaseFirestore _firestore;
  final IExpenseRepository _expenseRepo;
  final IInstallmentRepository _installmentRepo;

  InstallmentReconciliationService({
    FirebaseFirestore? firestore,
    required IExpenseRepository expenseRepo,
    required IInstallmentRepository installmentRepo,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _expenseRepo = expenseRepo,
        _installmentRepo = installmentRepo;

  /// Kullanıcı uygulamayı açtığında çalışan güvenli senkronizasyon.
  /// Kesim tarihi geçmiş taksitleri kontrol eder ve henüz harcama olarak
  /// eklenmemiş olanları idempotent anahtarla ekler.
  Future<int> reconcileDueInstallments({required String uid, String? teamId}) async {
    final now = DateTime.now();
    int addedCount = 0;

    try {
      // Aktif taksit planlarını çek
      final plansSnapshot = await _firestore
          .collection('installmentPlans')
          .where('ownerUid', isEqualTo: uid)
          .where('status', isEqualTo: 'active')
          .get();

      for (final doc in plansSnapshot.docs) {
        final plan = InstallmentPlan.fromMap(doc.data());
        final updatedSchedule = List.of(plan.installmentSchedule);
        bool planNeedsUpdate = false;

        for (int i = 0; i < updatedSchedule.length; i++) {
          final item = updatedSchedule[i];

          // Kesim tarihi geçmiş mi ve henüz harcama olarak düşmemiş mi?
          if (item.status == 'upcoming' && now.isAfter(item.statementCutoffDate)) {
            final idempotencyKey = '${plan.id}_${item.installmentNumber}_${item.statementPeriod}';

            // Zaten var mı kontrol et
            final existingDoc = await _firestore.collection('expenses').doc(idempotencyKey).get();
            if (!existingDoc.exists) {
              final newExpense = Expense(
                id: idempotencyKey,
                teamId: plan.teamId,
                ownerUid: plan.ownerUid,
                visibility: plan.visibility,
                title: '${plan.title} (Taksit ${item.installmentNumber}/${plan.totalInstallments})',
                amountInCents: item.amountInCents,
                currency: plan.currency,
                category: plan.category,
                date: item.statementCutoffDate,
                paymentMethod: 'credit_card',
                cardId: plan.cardId,
                cardLast4: plan.cardLast4,
                isInstallment: true,
                installmentPlanId: plan.id,
                installmentNumber: item.installmentNumber,
                totalInstallments: plan.totalInstallments,
                statementPeriod: item.statementPeriod,
                createdBy: 'client_reconciliation',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );

              await _expenseRepo.createExpense(newExpense);
              addedCount++;
            }

            // Schedule durumunu posted yap
            updatedSchedule[i] = StatementInstallmentScheduleItem(
              installmentNumber: item.installmentNumber,
              amountInCents: item.amountInCents,
              statementPeriod: item.statementPeriod,
              statementCutoffDate: item.statementCutoffDate,
              dueDate: item.dueDate,
              status: 'posted',
            );
            planNeedsUpdate = true;
          }
        }

        if (planNeedsUpdate) {
          final allPosted = updatedSchedule.every((s) => s.status == 'posted');
          final updatedPlan = plan.copyWith(
            installmentSchedule: updatedSchedule,
            status: allPosted ? 'completed' : 'active',
            updatedAt: DateTime.now(),
          );
          await _installmentRepo.updateInstallmentPlan(updatedPlan);
        }
      }

      debugPrint('[Reconciliation] Tamamlandı. Eklenen taksit harcaması: $addedCount');
    } catch (e) {
      debugPrint('[Reconciliation] Senkronizasyon hatası: $e');
    }

    return addedCount;
  }
}
