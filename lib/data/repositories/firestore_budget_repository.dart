import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/budget.dart';
import '../../domain/repositories/i_budget_repository.dart';

class FirestoreBudgetRepository implements IBudgetRepository {
  final FirebaseFirestore _firestore;

  FirestoreBudgetRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _budgetsCol =>
      _firestore.collection('budgets');

  @override
  Stream<Budget?> watchBudget({
    required String period,
    required String ownerUid,
    String? teamId,
  }) {
    Query<Map<String, dynamic>> query = _budgetsCol.where('period', isEqualTo: period);

    if (teamId != null) {
      query = query.where('teamId', isEqualTo: teamId);
    } else {
      query = query.where('ownerUid', isEqualTo: ownerUid).where('visibility', isEqualTo: 'personal');
    }

    return query.limit(1).snapshots().map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      final data = doc.data();
      data['id'] = doc.id;
      return Budget.fromMap(data);
    });
  }

  @override
  Future<void> saveBudget(Budget budget) async {
    await _budgetsCol.doc(budget.id).set(budget.toMap());
  }
}
