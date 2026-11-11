import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/installment_plan.dart';
import '../../domain/repositories/i_installment_repository.dart';

class FirestoreInstallmentRepository implements IInstallmentRepository {
  final FirebaseFirestore _firestore;

  FirestoreInstallmentRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _plansCol =>
      _firestore.collection('installmentPlans');

  @override
  Stream<List<InstallmentPlan>> watchInstallmentPlans({
    required String ownerUid,
    String? teamId,
    String? status,
  }) {
    Query<Map<String, dynamic>> query = _plansCol;

    if (teamId != null) {
      query = query.where('teamId', isEqualTo: teamId);
    } else {
      query = query.where('ownerUid', isEqualTo: ownerUid);
    }

    if (status != null && status.isNotEmpty) {
      query = query.where('status', isEqualTo: status);
    }

    return query.snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return InstallmentPlan.fromMap(data);
      }).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  @override
  Future<void> createInstallmentPlan(InstallmentPlan plan) async {
    await _plansCol.doc(plan.id).set(plan.toMap());
  }

  @override
  Future<void> updateInstallmentPlan(InstallmentPlan plan) async {
    await _plansCol.doc(plan.id).update(plan.toMap());
  }

  @override
  Future<void> cancelInstallmentPlan(String planId) async {
    await _plansCol.doc(planId).update({
      'status': 'cancelled',
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<InstallmentPlan?> getInstallmentPlanById(String planId) async {
    final doc = await _plansCol.doc(planId).get();
    if (!doc.exists || doc.data() == null) return null;
    final data = doc.data()!;
    data['id'] = doc.id;
    return InstallmentPlan.fromMap(data);
  }
}
