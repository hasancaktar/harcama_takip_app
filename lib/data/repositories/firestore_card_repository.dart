import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/credit_card.dart';
import '../../domain/repositories/i_card_repository.dart';

class FirestoreCardRepository implements ICardRepository {
  final FirebaseFirestore _firestore;

  FirestoreCardRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _cardsCol =>
      _firestore.collection('creditCards');

  @override
  Stream<List<CreditCard>> watchCards({required String ownerUid, String? teamId}) {
    // Kullanıcının kendi kartları
    return _cardsCol
        .where('ownerUid', isEqualTo: ownerUid)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return CreditCard.fromMap(data);
      }).toList();
    });
  }

  @override
  Future<void> createCard(CreditCard card) async {
    await _cardsCol.doc(card.id).set(card.toMap());
  }

  @override
  Future<void> updateCard(CreditCard card) async {
    await _cardsCol.doc(card.id).update(card.toMap());
  }

  @override
  Future<void> deleteCard(String cardId) async {
    await _cardsCol.doc(cardId).update({'isActive': false});
  }

  @override
  Future<CreditCard?> getCardById(String cardId) async {
    final doc = await _cardsCol.doc(cardId).get();
    if (!doc.exists || doc.data() == null) return null;
    final data = doc.data()!;
    data['id'] = doc.id;
    return CreditCard.fromMap(data);
  }
}
