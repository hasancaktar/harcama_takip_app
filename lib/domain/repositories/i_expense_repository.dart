import '../entities/expense.dart';

abstract class IExpenseRepository {
  /// Kullanıcının kişisel (takıma ait olmayan) harcamaları.
  Stream<List<Expense>> watchPersonalExpenses({
    required String uid,
    required List<String> periods,
  });

  /// Takımın tüm üyelerinin takım harcamaları.
  Stream<List<Expense>> watchTeamExpenses({
    required String teamId,
    required List<String> periods,
  });

  /// Bir kartın belirli ekstre dönemindeki harcamaları (kullanıcının kendi
  /// harcamaları ve kart takımla paylaşılıyorsa takım harcamaları).
  Stream<List<Expense>> watchCardExpenses({
    required String cardId,
    required String uid,
    String? sharedTeamId,
    required String period,
  });

  Stream<Expense?> watchExpense(String expenseId);
  Future<void> createExpense(Expense expense);
  Future<void> updateExpense(Expense expense);
  Future<void> softDeleteExpense(String expenseId, String deletedByUid);
}
