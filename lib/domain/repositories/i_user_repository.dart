import '../entities/user_profile.dart';

abstract class IUserRepository {
  Stream<UserProfile?> watchProfile(String uid);
  Future<UserProfile?> getProfile(String uid);

  /// Profil yoksa oluşturur; varsa e-posta/ad alanlarını günceller.
  Future<void> ensureProfile({
    required String uid,
    required String email,
    required String displayName,
  });
  Future<void> updateDisplayName(String uid, String displayName);
  Future<void> updateReminderSettings({
    required String uid,
    required bool enabled,
    required int hour,
    required int minute,
    required List<int> days,
  });
  Future<void> setActiveTeam(String uid, String? teamId);
  Future<void> addPushToken(String uid, String token);
  Future<void> removePushToken(String uid, String token);
}
