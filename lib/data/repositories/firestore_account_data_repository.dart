import 'package:cloud_firestore/cloud_firestore.dart';

/// Hesap silme sırasında kullanıcıya ait tüm Firestore verilerini temizler.
///
/// Silinenler: kullanıcının oluşturduğu harcamalar (kişisel + takım), taksit planları,
/// otomatik ödemeler, kartlar, araçlar, kişisel bütçeler, gönderilen öneriler, cihaz
/// kayıtları ve profil belgesi.
/// Takımlar: sahibi olunan takımlar arşivlenir, üye olunan takımlardan ayrılınır.
class FirestoreAccountDataRepository {
  final FirebaseFirestore _firestore;

  FirestoreAccountDataRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const int _batchLimit = 400;

  Future<void> deleteAllUserData(String uid) async {
    await _detachFromTeams(uid);
    await _deleteQuery(
      _firestore.collection('expenses').where('ownerUid', isEqualTo: uid),
    );
    await _deleteQuery(
      _firestore
          .collection('installmentPlans')
          .where('ownerUid', isEqualTo: uid),
    );
    await _deleteQuery(
      _firestore
          .collection('recurringPayments')
          .where('ownerUid', isEqualTo: uid),
    );
    await _deleteQuery(
      _firestore.collection('creditCards').where('ownerUid', isEqualTo: uid),
    );
    await _deleteQuery(
      _firestore.collection('vehicles').where('ownerUid', isEqualTo: uid),
    );
    await _deleteQuery(
      _firestore.collection('feedback').where('uid', isEqualTo: uid),
    );
    await _deleteQuery(
      _firestore
          .collection('budgets')
          .where('ownerUid', isEqualTo: uid)
          .where('visibility', isEqualTo: 'personal'),
    );
    await _deleteQuery(
      _firestore.collection('users').doc(uid).collection('devices'),
    );
    await _firestore.collection('users').doc(uid).delete();
  }

  Future<void> _detachFromTeams(String uid) async {
    final teams = await _firestore
        .collection('teams')
        .where('memberUids', arrayContains: uid)
        .get();
    for (final team in teams.docs) {
      final data = team.data();
      if (data['ownerUid'] == uid) {
        await team.reference.update({
          'isArchived': true,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      } else {
        final batch = _firestore.batch();
        batch.delete(team.reference.collection('members').doc(uid));
        batch.update(team.reference, {
          'memberUids': FieldValue.arrayRemove([uid]),
          'memberCount': FieldValue.increment(-1),
          'updatedAt': DateTime.now().toIso8601String(),
        });
        await batch.commit();
      }
    }
  }

  Future<void> _deleteQuery(Query<Map<String, dynamic>> query) async {
    while (true) {
      final snapshot = await query.limit(_batchLimit).get();
      if (snapshot.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (snapshot.docs.length < _batchLimit) return;
    }
  }
}
