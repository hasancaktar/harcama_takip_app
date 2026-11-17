import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/l10n/app_locale.dart';

/// `main()` içinde gerçek örnekle override edilir.
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

/// Tema tercihi cihazda kalıcı olarak saklanır.
class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    final stored = ref.watch(sharedPreferencesProvider)?.getString(_key);
    return ThemeMode.values.firstWhere(
      (m) => m.name == stored,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(sharedPreferencesProvider)?.setString(_key, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

/// Ağ bağlantısı durumu (çevrimdışı bandı için). Belirlenemezse çevrimiçi kabul edilir.
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  bool online(List<ConnectivityResult> r) =>
      r.any((c) => c != ConnectivityResult.none);
  try {
    yield online(await connectivity.checkConnectivity());
  } catch (_) {
    yield true;
  }
  yield* connectivity.onConnectivityChanged.map(online);
});

/// Uygulama dili. Cihazda saklanır; ilk açılışta cihaz dili Türkçe değilse İngilizce seçilir.
class LocaleController extends Notifier<Locale> {
  static const _key = 'language';

  @override
  Locale build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    var code = prefs?.getString(_key);
    if (code == null && prefs != null) {
      final device =
          WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      code = device == 'tr' ? 'tr' : 'en';
    }
    AppLocale.set(code ?? AppLocale.fallback);
    return AppLocale.locale;
  }

  Future<void> set(String code) async {
    AppLocale.set(code);
    state = AppLocale.locale;
    await ref.read(sharedPreferencesProvider)?.setString(_key, AppLocale.code);
  }
}

final localeProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);
