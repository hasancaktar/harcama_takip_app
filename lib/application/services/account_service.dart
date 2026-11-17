import 'package:harcama_takip/core/l10n/app_locale.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/error_messages.dart';
import '../providers/repository_providers.dart';

final accountServiceProvider = Provider<AccountService>(
  (ref) => AccountService(ref),
);

/// Oturum ve hesap düzeyindeki, birden fazla depoyu koordine eden işlemler.
class AccountService {
  final Ref _ref;
  AccountService(this._ref);

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final user = await _ref
        .read(authRepositoryProvider)
        .register(email: email, password: password, displayName: displayName);
    // Profil, doğrulamadan önce de sahibince yazılabilir (bkz. firestore.rules).
    try {
      await _ref
          .read(userRepositoryProvider)
          .ensureProfile(
            uid: user.uid,
            email: user.email,
            displayName: displayName.trim(),
          );
    } catch (e) {
      // Profil ilk doğrulanmış girişte yeniden oluşturulur (AppBootstrap).
      debugPrint(
        '[AccountService] Profil oluşturulamadı, sonra tekrar denenecek: $e',
      );
    }
  }

  Future<void> signOut() async {
    try {
      await _ref.read(pushTokenServiceProvider).unregister();
    } catch (e) {
      debugPrint('[AccountService] Push token silinemedi: $e');
    }
    try {
      await _ref.read(notificationServiceProvider).cancelReminders();
    } catch (e) {
      debugPrint('[AccountService] Hatırlatıcılar iptal edilemedi: $e');
    }
    await _ref.read(authRepositoryProvider).signOut();
  }

  Future<void> updateDisplayName(String displayName) async {
    final auth = _ref.read(authRepositoryProvider);
    final user = auth.currentUser;
    if (user == null) throw AppException('Oturum bulunamadı.'.tr);
    final trimmed = displayName.trim();
    await auth.updateDisplayName(trimmed);
    await _ref
        .read(userRepositoryProvider)
        .updateDisplayName(user.uid, trimmed);
    try {
      await _ref
          .read(teamRepositoryProvider)
          .updateMemberDisplayName(uid: user.uid, displayName: trimmed);
    } catch (e) {
      debugPrint('[AccountService] Takım üyeliği adı güncellenemedi: $e');
    }
  }

  /// Hesabı ve kullanıcıya ait tüm verileri kalıcı olarak siler.
  Future<void> deleteAccount({required String password}) async {
    final auth = _ref.read(authRepositoryProvider);
    final user = auth.currentUser;
    if (user == null) throw AppException('Oturum bulunamadı.'.tr);

    await auth.reauthenticate(password);
    try {
      await _ref.read(pushTokenServiceProvider).unregister();
    } catch (e) {
      debugPrint('[AccountService] Push token silinemedi: $e');
    }
    await _ref.read(accountDataRepositoryProvider).deleteAllUserData(user.uid);
    try {
      await _ref.read(notificationServiceProvider).cancelReminders();
    } catch (e) {
      debugPrint('[AccountService] Hatırlatıcılar iptal edilemedi: $e');
    }
    await auth.deleteCurrentUser();
  }
}
