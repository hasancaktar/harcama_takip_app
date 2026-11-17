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
    await _ref.read(pushTokenServiceProvider).unregister();
    await _ref.read(notificationServiceProvider).cancelReminders();
    await _ref.read(authRepositoryProvider).signOut();
  }

  Future<void> updateDisplayName(String displayName) async {
    final auth = _ref.read(authRepositoryProvider);
    final user = auth.currentUser;
    if (user == null) throw AppException('Oturum bulunamadı.'.tr);
    await auth.updateDisplayName(displayName);
    await _ref
        .read(userRepositoryProvider)
        .updateDisplayName(user.uid, displayName.trim());
  }

  /// Hesabı ve kullanıcıya ait tüm verileri kalıcı olarak siler.
  Future<void> deleteAccount({required String password}) async {
    final auth = _ref.read(authRepositoryProvider);
    final user = auth.currentUser;
    if (user == null) throw AppException('Oturum bulunamadı.'.tr);

    await auth.reauthenticate(password);
    await _ref.read(pushTokenServiceProvider).unregister();
    await _ref.read(accountDataRepositoryProvider).deleteAllUserData(user.uid);
    await _ref.read(notificationServiceProvider).cancelReminders();
    await auth.deleteCurrentUser();
  }
}
