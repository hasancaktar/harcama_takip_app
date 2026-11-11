import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/firebase/firebase_initialization.dart';
import 'core/theme/app_theme.dart';
import 'presentation/navigation/app_router.dart';
import 'presentation/screens/settings/theme_language_screen.dart';
import 'presentation/screens/splash/firebase_setup_guide_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final initResult = await FirebaseInitialization.initialize();

  runApp(
    ProviderScope(
      child: ExpenseTrackerApp(initResult: initResult),
    ),
  );
}

class ExpenseTrackerApp extends ConsumerWidget {
  final FirebaseInitResult initResult;

  const ExpenseTrackerApp({super.key, required this.initResult});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Firebase yapılandırılmamışsa rehber ekranı göster
    if (!initResult.isSuccess) {
      return MaterialApp(
        title: 'Harcama & Taksit Takip',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: FirebaseSetupGuideScreen(errorMessage: initResult.errorMessage),
        debugShowCheckedModeBanner: false,
      );
    }

    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(appThemeModeProvider);

    return MaterialApp.router(
      title: 'Harcama & Taksit Takip',
      routerConfig: router,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('tr', 'TR'),
        Locale('en', 'US'),
      ],
      locale: const Locale('tr', 'TR'),
    );
  }
}
