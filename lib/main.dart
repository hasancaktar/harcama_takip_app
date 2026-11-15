import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'application/providers/settings_providers.dart';
import 'core/constants/app_constants.dart';
import 'core/firebase/firebase_initialization.dart';
import 'core/theme/app_theme.dart';
import 'presentation/navigation/app_router.dart';
import 'presentation/screens/splash/startup_error_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Web'de "#/" yerine temiz URL'ler (Firebase Hosting'deki SPA yönlendirmesiyle uyumlu).
  usePathUrlStrategy();
  // context.push ile açılan sayfalar da tarayıcı adres çubuğuna yansısın (yenileme/derin bağlantı).
  GoRouter.optionURLReflectsImperativeAPIs = true;
  Intl.defaultLocale = AppConstants.defaultLocale;
  await initializeDateFormatting(AppConstants.defaultLocale);

  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (e) {
    debugPrint('[main] SharedPreferences açılamadı: $e');
  }

  final initResult = await FirebaseInitialization.initialize();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: ExpenseTrackerApp(initResult: initResult),
    ),
  );
}

const _localizationsDelegates = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];
const _supportedLocales = [Locale('tr', 'TR')];

class ExpenseTrackerApp extends ConsumerWidget {
  final FirebaseInitResult initResult;

  const ExpenseTrackerApp({super.key, required this.initResult});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    if (!initResult.isSuccess) {
      return MaterialApp(
        title: AppConstants.appName,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        debugShowCheckedModeBanner: false,
        localizationsDelegates: _localizationsDelegates,
        supportedLocales: _supportedLocales,
        locale: const Locale('tr', 'TR'),
        home: StartupErrorScreen(
          technicalDetails: kDebugMode ? initResult.errorMessage : null,
        ),
      );
    }

    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: AppConstants.appName,
      routerConfig: router,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: _localizationsDelegates,
      supportedLocales: _supportedLocales,
      locale: const Locale('tr', 'TR'),
    );
  }
}
