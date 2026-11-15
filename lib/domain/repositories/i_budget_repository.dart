import '../entities/budget.dart';

abstract class IBudgetRepository {
  Stream<Budget?> watchBudget({
    required String ownerUid,
    String? teamId,
    required String period,
  });
  Future<void> saveBudget(Budget budget);
  Future<void> deleteBudget(String budgetId);
}
