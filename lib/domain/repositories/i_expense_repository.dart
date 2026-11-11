import '../entities/expense.dart';

abstract class IExpenseRepository {
  Stream<List<Expense>> watchExpenses({
    String? teamId,
    required String ownerUid,
    required String statementPeriod,
    String? visibility, // 'all' | 'personal' | 'team'
  });

  Future<void> createExpense(Expense expense);
  Future<void> updateExpense(Expense expense);
  Future<void> softDeleteExpense(String expenseId, String deletedByUid);
  Future<Expense?> getExpenseById(String expenseId);
}
