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
  Stream<List<Budget>> watchBudgets({
    required String ownerUid,
    String? teamId,
  }) {
    final Query<Map<String, dynamic>> query = teamId != null
        ? _col
              .where('teamId', isEqualTo: teamId)
              .where('visibility', isEqualTo: 'team')
        : _col
              .where('ownerUid', isEqualTo: ownerUid)
              .where('visibility', isEqualTo: 'personal');

    return query.snapshots().map(
      (snapshot) => snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Budget.fromMap(data);
      }).toList(),
    );
  }

  @override
  Future<void> saveBudget(Budget budget) =>
      _col.doc(budget.id).set(budget.toMap());

  @override
  Future<void> deleteBudget(String budgetId) => _col.doc(budgetId).delete();
}
