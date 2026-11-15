import '../entities/expense.dart';
import '../entities/installment_plan.dart';

abstract class IInstallmentRepository {
  Stream<List<InstallmentPlan>> watchOwnPlans(String uid);
  Stream<List<InstallmentPlan>> watchTeamPlans(String teamId);
  Stream<InstallmentPlan?> watchPlan(String planId);
  Future<List<InstallmentPlan>> getActiveOwnPlans(String uid);

  /// Planı ve vadesi gelmiş taksit harcamalarını tek atomik işlemle yazar.
  Future<void> savePlanWithPostings(
    InstallmentPlan plan,
    List<Expense> postings,
  );

  /// Plan iptal edilir; işlenmiş taksitler korunur, kalanlar işlenmez.
  Future<void> cancelPlan(String planId);
}
