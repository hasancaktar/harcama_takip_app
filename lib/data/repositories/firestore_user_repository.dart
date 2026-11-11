import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/i_user_repository.dart';

class FirestoreUserRepository implements IUserRepository {
  final FirebaseFirestore _firestore;

  FirestoreUserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCol =>
      _firestore.collection('users');

  @override
  Stream<UserProfile?> watchProfile(String uid) {
    return _usersCol.doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      final data = doc.data()!;
      data['uid'] = doc.id;
      return UserProfile.fromMap(data);
    });
  }

  @override
  Future<UserProfile?> getProfile(String uid) async {
    final doc = await _usersCol.doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    final data = doc.data()!;
    data['uid'] = doc.id;
    return UserProfile.fromMap(data);
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    await _usersCol.doc(profile.uid).set(profile.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> updateReminderSettings({
    required String uid,
    required bool enabled,
    required int hour,
    required int minute,
    required List<int> days,
  }) async {
    await _usersCol.doc(uid).update({
      'dailyReminderEnabled': enabled,
      'dailyReminderHour': hour,
      'dailyReminderMinute': minute,
      'dailyReminderDays': days,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> setActiveTeam(String uid, String? teamId) async {
    await _usersCol.doc(uid).update({
      'activeTeamId': teamId,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }
}
