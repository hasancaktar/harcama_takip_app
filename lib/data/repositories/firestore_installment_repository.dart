import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/utils/statement_calculator.dart';
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
  Future<void> cancelPlan(
    InstallmentPlan plan, {
    required String actorUid,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final stamp = at.toIso8601String();
    final batch = _firestore.batch();
    final schedule = <StatementInstallmentScheduleItem>[];
    for (final item in plan.installmentSchedule) {
      if (item.isPosted && !InstallmentPlan.isBilledAt(item, at)) {
        batch.update(
          _firestore
              .collection('expenses')
              .doc(InstallmentPostingPolicy.expenseIdFor(plan.id, item)),
          {
            'status': 'deleted',
            'deletedAt': stamp,
            'deletedBy': actorUid,
            'updatedAt': stamp,
          },
        );
        schedule.add(item.copyWith(status: 'upcoming'));
      } else {
        schedule.add(item);
      }
    }
    batch.update(_col.doc(plan.id), {
      'status': 'cancelled',
      'installmentSchedule': schedule.map((s) => s.toMap()).toList(),
      'updatedAt': stamp,
    });
    await batch.commit();
  }
}
