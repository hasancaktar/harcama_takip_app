import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/expense.dart';
import '../../domain/entities/installment_plan.dart';
import '../../domain/repositories/i_installment_repository.dart';

class FirestoreInstallmentRepository implements IInstallmentRepository {
  final FirebaseFirestore _firestore;

  FirestoreInstallmentRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('installmentPlans');

  static InstallmentPlan _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    data['id'] = doc.id;
    return InstallmentPlan.fromMap(data);
  }

  static List<InstallmentPlan> _sorted(QuerySnapshot<Map<String, dynamic>> s) =>
      s.docs.map(_fromDoc).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Stream<List<InstallmentPlan>> watchOwnPlans(String uid) {
    return _col.where('ownerUid', isEqualTo: uid).snapshots().map(_sorted);
  }

  @override
  Stream<List<InstallmentPlan>> watchTeamPlans(String teamId) {
    return _col
        .where('teamId', isEqualTo: teamId)
        .where('visibility', isEqualTo: 'team')
        .snapshots()
        .map(_sorted);
  }

  @override
  Stream<InstallmentPlan?> watchPlan(String planId) {
    return _col
        .doc(planId)
        .snapshots()
        .map((doc) => doc.exists ? _fromDoc(doc) : null);
  }

  @override
  Future<List<InstallmentPlan>> getActiveOwnPlans(String uid) async {
    final snapshot = await _col
        .where('ownerUid', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .get();
    return snapshot.docs.map(_fromDoc).toList();
  }

  @override
  Future<void> savePlanWithPostings(
    InstallmentPlan plan,
    List<Expense> postings,
  ) async {
    final batch = _firestore.batch();
    batch.set(_col.doc(plan.id), plan.toMap());
    for (final expense in postings) {
      batch.set(
        _firestore.collection('expenses').doc(expense.id),
        expense.toMap(),
      );
    }
    await batch.commit();
  }

  @override
  Future<void> cancelPlan(String planId) {
    return _col.doc(planId).update({
      'status': 'cancelled',
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }
}
