import '../entities/credit_card.dart';

abstract class ICardRepository {
  Stream<List<CreditCard>> watchCards({required String ownerUid, String? teamId});
  Future<void> createCard(CreditCard card);
  Future<void> updateCard(CreditCard card);
  Future<void> deleteCard(String cardId);
  Future<CreditCard?> getCardById(String cardId);
}
