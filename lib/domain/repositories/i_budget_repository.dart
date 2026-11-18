import '../entities/budget.dart';

abstract class IBudgetRepository {
  /// Çalışma alanının (kişisel veya takım) tüm aylardaki bütçeleri.
  /// Seçili ay için geçerli bütçe [Budget.resolveForPeriod] ile bulunur.
  Stream<List<Budget>> watchBudgets({required String ownerUid, String? teamId});
  Future<void> saveBudget(Budget budget);
  Future<void> deleteBudget(String budgetId);
}
