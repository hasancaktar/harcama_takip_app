import '../entities/installment_plan.dart';

abstract class IInstallmentRepository {
  Stream<List<InstallmentPlan>> watchInstallmentPlans({
    required String ownerUid,
    String? teamId,
    String? status,
  });

  Future<void> createInstallmentPlan(InstallmentPlan plan);
  Future<void> updateInstallmentPlan(InstallmentPlan plan);
  Future<void> cancelInstallmentPlan(String planId);
  Future<InstallmentPlan?> getInstallmentPlanById(String planId);
}
