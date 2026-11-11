import '../entities/user_profile.dart';

abstract class IUserRepository {
  Stream<UserProfile?> watchProfile(String uid);
  Future<UserProfile?> getProfile(String uid);
  Future<void> saveProfile(UserProfile profile);
  Future<void> updateReminderSettings({
    required String uid,
    required bool enabled,
    required int hour,
    required int minute,
    required List<int> days,
  });
  Future<void> setActiveTeam(String uid, String? teamId);
}
