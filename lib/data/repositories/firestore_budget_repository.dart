import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/budget.dart';
import '../../domain/repositories/i_budget_repository.dart';

class FirestoreBudgetRepository implements IBudgetRepository {
  final FirebaseFirestore _firestore;

  FirestoreBudgetRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('budgets');

  @override
  Stream<Budget?> watchBudget({
    required String ownerUid,
    String? teamId,
    required String period,
  }) {
    final Query<Map<String, dynamic>> query = teamId != null
        ? _col
              .where('teamId', isEqualTo: teamId)
              .where('visibility', isEqualTo: 'team')
              .where('period', isEqualTo: period)
        : _col
              .where('ownerUid', isEqualTo: ownerUid)
              .where('visibility', isEqualTo: 'personal')
              .where('period', isEqualTo: period);

    final canonicalId = Budget.idFor(
      ownerUid: ownerUid,
      teamId: teamId,
      period: period,
    );

    return query.snapshots().map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final budgets = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Budget.fromMap(data);
      }).toList();
      // Eski sürümlerden kalan rastgele kimlikli kayıtlar da okunur; kanonik kayıt önceliklidir.
      for (final b in budgets) {
        if (b.id == canonicalId) return b;
      }
      budgets.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return budgets.first;
    });
  }

  @override
  Future<void> saveBudget(Budget budget) =>
      _col.doc(budget.id).set(budget.toMap());

  @override
  Future<void> deleteBudget(String budgetId) => _col.doc(budgetId).delete();
}
