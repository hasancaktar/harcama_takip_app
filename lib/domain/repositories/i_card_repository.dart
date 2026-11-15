import '../entities/credit_card.dart';

abstract class ICardRepository {
  Stream<List<CreditCard>> watchOwnCards(String uid);
  Stream<List<CreditCard>> watchTeamSharedCards(String teamId);
  Stream<CreditCard?> watchCard(String cardId);
  Future<void> saveCard(CreditCard card);

  /// Kartı pasifleştirir; geçmiş harcamalar korunur.
  Future<void> deactivateCard(String cardId);
}
