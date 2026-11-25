import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';

/// Mağazada bekleyen güncelleme.
@immutable
class AvailableUpdate {
  /// Play'deki sürüm kodu (bilinmiyorsa 0).
  final int versionCode;
  const AvailableUpdate({required this.versionCode});
}

/// Yeni sürüm var mı? Hiçbir durumda hata fırlatmaz; bilinemiyorsa `null`.
abstract class IAppUpdateChecker {
  Future<AvailableUpdate?> check();

  /// Uygulamanın mağaza sayfasını açar (hata yutulur).
  Future<void> openStore();
}

/// Google Play'in uygulama içi güncelleme bilgisi. Yalnızca Play'den kurulmuş
/// Android uygulamasında sonuç verir; web'de, Play dışı kurulumda, internet
/// yokken veya Play hata verdiğinde `null` döner.
class PlayAppUpdateChecker implements IAppUpdateChecker {
  static const String storeUrl =
      'https://play.google.com/store/apps/details?id=com.faydalab.harcama_takip';

  @override
  Future<AvailableUpdate?> check() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final info = await InAppUpdate.checkForUpdate().timeout(
        const Duration(seconds: 10),
      );
      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return null;
      }
      final code = info.availableVersionCode;
      if (code != null && code <= AppConstants.appBuildNumber) return null;
      return AvailableUpdate(versionCode: code ?? 0);
    } catch (_) {
      // Bilerek yok sayılır: güncelleme kontrolü kullanıcıyı rahatsız etmemeli.
      return null;
    }
  }

  @override
  Future<void> openStore() async {
    try {
      await launchUrl(
        Uri.parse(storeUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }
}
