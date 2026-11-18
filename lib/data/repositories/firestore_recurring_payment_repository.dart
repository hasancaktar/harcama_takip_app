import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/expense.dart';
import '../../domain/entities/recurring_payment.dart';
import '../../domain/repositories/i_recurring_payment_repository.dart';

class FirestoreRecurringPaymentRepository
    implements IRecurringPaymentRepository {
  final FirebaseFirestore _firestore;

  FirestoreRecurringPaymentRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('recurringPayments');

  static RecurringPayment _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    data['id'] = doc.id;
    return RecurringPayment.fromMap(data);
  }

  static List<RecurringPayment> _sorted(
    QuerySnapshot<Map<String, dynamic>> s,
  ) =>
      s.docs.map(_fromDoc).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Stream<List<RecurringPayment>> watchOwn(String uid) =>
      _col.where('ownerUid', isEqualTo: uid).snapshots().map(_sorted);

  @override
  Stream<List<RecurringPayment>> watchTeam(String teamId) => _col
      .where('teamId', isEqualTo: teamId)
      .where('visibility', isEqualTo: 'team')
      .snapshots()
      .map(_sorted);

  @override
  Stream<RecurringPayment?> watch(String id) =>
      _col.doc(id).snapshots().map((doc) => doc.exists ? _fromDoc(doc) : null);

  @override
  Future<List<RecurringPayment>> getActiveOwn(String uid) async {
    final snapshot = await _col
        .where('ownerUid', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .get();
    return snapshot.docs.map(_fromDoc).toList();
  }

  @override
  Future<void> save(
    RecurringPayment payment, {
    List<Expense> postings = const [],
    List<String> deleteExpenseIds = const [],
    required String actorUid,
  }) async {
    final batch = _firestore.batch();
    batch.set(_col.doc(payment.id), payment.toMap());
    final expenses = _firestore.collection('expenses');
    for (final e in postings) {
      batch.set(expenses.doc(e.id), e.toMap());
    }
    final stamp = DateTime.now().toIso8601String();
    for (final id in deleteExpenseIds) {
      batch.update(expenses.doc(id), {
        'status': 'deleted',
        'deletedAt': stamp,
        'deletedBy': actorUid,
        'updatedAt': stamp,
      });
    }
    await batch.commit();
  }
}
