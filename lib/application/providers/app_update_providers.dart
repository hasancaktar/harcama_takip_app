import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/app_update_checker.dart';

final appUpdateCheckerProvider = Provider<IAppUpdateChecker>(
  (ref) => PlayAppUpdateChecker(),
);

/// Oturum başına bir kez bakılan güncelleme durumu. Hata olursa `null`
/// (kullanıcıya hiçbir şey gösterilmez).
final appUpdateProvider = FutureProvider<AvailableUpdate?>((ref) async {
  try {
    return await ref.watch(appUpdateCheckerProvider).check();
  } catch (_) {
    return null;
  }
});
