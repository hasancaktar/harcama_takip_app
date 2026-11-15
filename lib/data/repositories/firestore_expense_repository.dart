import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/utils/stream_utils.dart';
import '../../domain/entities/expense.dart';
import '../../domain/repositories/i_expense_repository.dart';

class FirestoreExpenseRepository implements IExpenseRepository {
  final FirebaseFirestore _firestore;

  FirestoreExpenseRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('expenses');

  static Expense _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    data['id'] = doc.id;
    return Expense.fromMap(data);
  }

  static List<Expense> _sorted(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final list = snapshot.docs.map(_fromDoc).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Query<Map<String, dynamic>> _withPeriods(
    Query<Map<String, dynamic>> query,
    List<String> periods,
  ) {
    if (periods.length == 1) {
      return query.where('statementPeriod', isEqualTo: periods.first);
    }
    return query.where('statementPeriod', whereIn: periods);
  }

  @override
  Stream<List<Expense>> watchPersonalExpenses({
    required String uid,
    required List<String> periods,
  }) {
    if (periods.isEmpty) return Stream.value(const []);
    final query = _withPeriods(
      _col
          .where('ownerUid', isEqualTo: uid)
          .where('visibility', isEqualTo: 'personal')
          .where('status', isEqualTo: 'active'),
      periods,
    );
    return query.snapshots().map(_sorted);
  }

  @override
  Stream<List<Expense>> watchTeamExpenses({
    required String teamId,
    required List<String> periods,
  }) {
    if (periods.isEmpty) return Stream.value(const []);
    final query = _withPeriods(
      _col
          .where('teamId', isEqualTo: teamId)
          .where('visibility', isEqualTo: 'team')
          .where('status', isEqualTo: 'active'),
      periods,
    );
    return query.snapshots().map(_sorted);
  }

  @override
  Stream<List<Expense>> watchCardExpenses({
    required String cardId,
    required String uid,
    String? sharedTeamId,
    required String period,
  }) {
    final own = _col
        .where('cardId', isEqualTo: cardId)
        .where('ownerUid', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .where('statementPeriod', isEqualTo: period)
        .snapshots()
        .map(_sorted);
    if (sharedTeamId == null) return own;

    final team = _col
        .where('cardId', isEqualTo: cardId)
        .where('teamId', isEqualTo: sharedTeamId)
        .where('visibility', isEqualTo: 'team')
        .where('status', isEqualTo: 'active')
        .where('statementPeriod', isEqualTo: period)
        .snapshots()
        .map(_sorted);
    return mergeListStreams<Expense>(
      [own, team],
      idOf: (e) => e.id,
    ).map((list) => list..sort((a, b) => b.date.compareTo(a.date)));
  }

  @override
  Stream<Expense?> watchExpense(String expenseId) {
    return _col.doc(expenseId).snapshots().map((doc) {
      if (!doc.exists) return null;
      final expense = _fromDoc(doc);
      return expense.status == 'active' ? expense : null;
    });
  }

  @override
  Future<void> createExpense(Expense expense) =>
      _col.doc(expense.id).set(expense.toMap());

  @override
  Future<void> updateExpense(Expense expense) =>
      _col.doc(expense.id).set(expense.toMap());

  @override
  Future<void> softDeleteExpense(String expenseId, String deletedByUid) {
    final now = DateTime.now().toIso8601String();
    return _col.doc(expenseId).update({
      'status': 'deleted',
      'deletedAt': now,
      'deletedBy': deletedByUid,
      'updatedAt': now,
    });
  }
}
