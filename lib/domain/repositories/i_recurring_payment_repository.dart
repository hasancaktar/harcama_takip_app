import '../entities/expense.dart';
import '../entities/recurring_payment.dart';

abstract class IRecurringPaymentRepository {
  Stream<List<RecurringPayment>> watchOwn(String uid);
  Stream<List<RecurringPayment>> watchTeam(String teamId);
  Stream<RecurringPayment?> watch(String id);
  Future<List<RecurringPayment>> getActiveOwn(String uid);

  /// Ödemeyi, yeni/yeniden yazılan aylık harcamaları ([postings]) ve silinecek
  /// aylık harcamaları ([deleteExpenseIds], soft delete) tek atomik yığında yazar.
  Future<void> save(
    RecurringPayment payment, {
    List<Expense> postings = const [],
    List<String> deleteExpenseIds = const [],
    required String actorUid,
  });
}
