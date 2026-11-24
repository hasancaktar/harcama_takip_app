import '../entities/debit_card.dart';

abstract class IDebitCardRepository {
  /// Kullanıcının etkin banka kartları (eklenme sırasıyla).
  Stream<List<DebitCard>> watchOwnCards(String uid);
  Stream<DebitCard?> watchCard(String cardId);
  Future<void> saveCard(DebitCard card);

  /// Kartı listeden kaldırır; geçmiş harcamalar son 4 haneyle kalır.
  Future<void> deactivateCard(String cardId);
}
