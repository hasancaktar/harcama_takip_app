import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/debit_card.dart';
import '../../domain/repositories/i_debit_card_repository.dart';

class FirestoreDebitCardRepository implements IDebitCardRepository {
  final FirebaseFirestore _firestore;

  FirestoreDebitCardRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('debitCards');

  static DebitCard _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    data['id'] = doc.id;
    return DebitCard.fromMap(data);
  }

  @override
  Stream<List<DebitCard>> watchOwnCards(String uid) => _col
      .where('ownerUid', isEqualTo: uid)
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map(
        (s) =>
            s.docs.map(_fromDoc).toList()
              ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
      );

  @override
  Stream<DebitCard?> watchCard(String cardId) => _col
      .doc(cardId)
      .snapshots()
      .map((doc) => doc.exists ? _fromDoc(doc) : null);

  @override
  Future<void> saveCard(DebitCard card) => _col.doc(card.id).set(card.toMap());

  @override
  Future<void> deactivateCard(String cardId) => _col.doc(cardId).update({
    'isActive': false,
    'updatedAt': DateTime.now().toIso8601String(),
  });
}
