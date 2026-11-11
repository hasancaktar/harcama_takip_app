import '../entities/budget.dart';

abstract class IBudgetRepository {
  Stream<Budget?> watchBudget({
    required String period,
    required String ownerUid,
    String? teamId,
  });

  Future<void> saveBudget(Budget budget);
}
