import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/i_user_repository.dart';

class FirestoreUserRepository implements IUserRepository {
  final FirebaseFirestore _firestore;

  FirestoreUserRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('users');

  static UserProfile? _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    if (!doc.exists || doc.data() == null) return null;
    final data = doc.data()!;
    data['uid'] = doc.id;
    return UserProfile.fromMap(data);
  }

  String get _now => DateTime.now().toIso8601String();

  @override
  Stream<UserProfile?> watchProfile(String uid) =>
      _col.doc(uid).snapshots().map(_fromDoc);

  @override
  Future<UserProfile?> getProfile(String uid) async =>
      _fromDoc(await _col.doc(uid).get());

  @override
  Future<void> ensureProfile({
    required String uid,
    required String email,
    required String displayName,
  }) async {
    final ref = _col.doc(uid);
    final snapshot = await ref.get();
    if (!snapshot.exists) {
      final now = DateTime.now();
      final profile = UserProfile(
        uid: uid,
        email: email,
        displayName: displayName,
        createdAt: now,
        updatedAt: now,
      );
      await ref.set(profile.toMap());
      return;
    }
    final data = snapshot.data() ?? {};
    final updates = <String, dynamic>{};
    if (data['email'] != email) updates['email'] = email;
    if (displayName.isNotEmpty && data['displayName'] != displayName) {
      updates['displayName'] = displayName;
    }
    if (updates.isNotEmpty) {
      updates['updatedAt'] = _now;
      await ref.update(updates);
    }
  }

  @override
  Future<void> updateDisplayName(String uid, String displayName) {
    return _col.doc(uid).set({
      'displayName': displayName,
      'updatedAt': _now,
    }, SetOptions(merge: true));
  }

  @override
  Future<void> updateReminderSettings({
    required String uid,
    required bool enabled,
    required int hour,
    required int minute,
    required List<int> days,
  }) {
    return _col.doc(uid).set({
      'dailyReminderEnabled': enabled,
      'dailyReminderHour': hour,
      'dailyReminderMinute': minute,
      'dailyReminderDays': days,
      'updatedAt': _now,
    }, SetOptions(merge: true));
  }

  @override
  Future<void> setActiveTeam(String uid, String? teamId) {
    return _col.doc(uid).set({
      'activeTeamId': teamId,
      'updatedAt': _now,
    }, SetOptions(merge: true));
  }

  @override
  Future<void> setPushEnabled(String uid, bool enabled) {
    return _col.doc(uid).set({
      'pushEnabled': enabled,
      'updatedAt': _now,
    }, SetOptions(merge: true));
  }

  @override
  Future<void> setLanguage(String uid, String languageCode) {
    return _col.doc(uid).set({
      'language': languageCode,
      'updatedAt': _now,
    }, SetOptions(merge: true));
  }

  @override
  Future<void> addPushToken(String uid, String token) {
    return _col.doc(uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> removePushToken(String uid, String token) {
    return _col.doc(uid).set({
      'fcmTokens': FieldValue.arrayRemove([token]),
    }, SetOptions(merge: true));
  }
}
