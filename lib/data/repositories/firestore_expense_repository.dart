import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/expense.dart';
import '../../domain/repositories/i_expense_repository.dart';

class FirestoreExpenseRepository implements IExpenseRepository {
  final FirebaseFirestore _firestore;

  FirestoreExpenseRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _expensesCol =>
      _firestore.collection('expenses');

  @override
  Stream<List<Expense>> watchExpenses({
    String? teamId,
    required String ownerUid,
    required String statementPeriod,
    String? visibility, // 'all' | 'personal' | 'team'
  }) {
    Query<Map<String, dynamic>> query = _expensesCol.where('status', isEqualTo: 'active');

    if (statementPeriod.isNotEmpty) {
      query = query.where('statementPeriod', isEqualTo: statementPeriod);
    }

    if (visibility == 'team' && teamId != null) {
      query = query.where('teamId', isEqualTo: teamId).where('visibility', isEqualTo: 'team');
    } else if (visibility == 'personal') {
      query = query.where('ownerUid', isEqualTo: ownerUid).where('visibility', isEqualTo: 'personal');
    } else {
      // 'all' veya varsayılan: Takım seçiliyse o takımın harcamaları + kullanıcının kişisel harcamaları
      if (teamId != null) {
        // İki stream birleştirilebilir veya istemcide filtrelenebilir.
        // Burada basit ve güvenli: Takım seçiliyken takım harcamalarını dinler
        query = query.where('teamId', isEqualTo: teamId);
      } else {
        query = query.where('ownerUid', isEqualTo: ownerUid);
      }
    }

    return query.snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Expense.fromMap(data);
      }).toList();

      // Tarihe göre azalan sıralama (En yeni en üstte)
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  @override
  Future<void> createExpense(Expense expense) async {
    await _expensesCol.doc(expense.id).set(expense.toMap());
  }

  @override
  Future<void> updateExpense(Expense expense) async {
    await _expensesCol.doc(expense.id).update(expense.toMap());
  }

  @override
  Future<void> softDeleteExpense(String expenseId, String deletedByUid) async {
    await _expensesCol.doc(expenseId).update({
      'status': 'deleted',
      'deletedAt': DateTime.now().toIso8601String(),
      'deletedBy': deletedByUid,
    });
  }

  @override
  Future<Expense?> getExpenseById(String expenseId) async {
    final doc = await _expensesCol.doc(expenseId).get();
    if (!doc.exists || doc.data() == null) return null;
    final data = doc.data()!;
    data['id'] = doc.id;
    return Expense.fromMap(data);
  }
}
