import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/credit_card.dart';
import '../../domain/repositories/i_card_repository.dart';

class FirestoreCardRepository implements ICardRepository {
  final FirebaseFirestore _firestore;

  FirestoreCardRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('creditCards');

  static CreditCard _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    data['id'] = doc.id;
    return CreditCard.fromMap(data);
  }

  static List<CreditCard> _sorted(QuerySnapshot<Map<String, dynamic>> s) =>
      s.docs.map(_fromDoc).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  @override
  Stream<List<CreditCard>> watchOwnCards(String uid) {
    return _col
        .where('ownerUid', isEqualTo: uid)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(_sorted);
  }

  @override
  Stream<List<CreditCard>> watchTeamSharedCards(String teamId) {
    return _col
        .where('teamId', isEqualTo: teamId)
        .where('isSharedWithTeam', isEqualTo: true)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(_sorted);
  }

  @override
  Stream<CreditCard?> watchCard(String cardId) {
    return _col
        .doc(cardId)
        .snapshots()
        .map((doc) => doc.exists ? _fromDoc(doc) : null);
  }

  @override
  Future<void> saveCard(CreditCard card) => _col.doc(card.id).set(card.toMap());

  @override
  Future<void> deactivateCard(String cardId) {
    return _col.doc(cardId).update({
      'isActive': false,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }
}
