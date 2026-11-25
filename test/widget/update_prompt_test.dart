import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:harcama_takip/application/providers/settings_providers.dart';
import 'package:harcama_takip/core/firebase/firebase_initialization.dart';
import 'package:harcama_takip/data/services/app_update_checker.dart';
import 'package:harcama_takip/domain/entities/app_user.dart';
import 'package:harcama_takip/main.dart';
import 'package:harcama_takip/presentation/navigation/app_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

class _Backend extends TestBackend {
  final _auth = FakeAuthRepository(
    initialUser: const AppUser(
      uid: 'u-ayse',
      email: 'ayse@example.com',
      displayName: 'Ayşe Yılmaz',
      emailVerified: true,
    ),
  );

  @override
  FakeAuthRepository get auth => _auth;
}

Future<void> _settle(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<GoRouter> _pump(
  WidgetTester tester,
  TestBackend backend,
  SharedPreferences prefs,
) async {
  tester.view.physicalSize = const Size(420, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...backend.overrides,
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const ExpenseTrackerApp(
        initResult: FirebaseInitResult(isSuccess: true),
      ),
    ),
  );
  await _settle(tester);
  return ProviderScope.containerOf(
    tester.element(find.byType(ExpenseTrackerApp)),
  ).read(appRouterProvider);
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

Future<SharedPreferences> _prefs() async {
  SharedPreferences.setMockInitialValues({'language': 'tr'});
  return SharedPreferences.getInstance();
}

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  testWidgets(
    'yeni sürüm varsa açılışta sorulur; Güncelle mağazayı açar, aynı gün tekrar sorulmaz',
    (tester) async {
      final prefs = await _prefs();
      final backend = _Backend();
      backend.appUpdates.update = const AvailableUpdate(versionCode: 7);
      await _pump(tester, backend, prefs);

      expect(find.text('Yeni sürüm mevcut'), findsOneWidget);
      expect(find.text('Sonra'), findsOneWidget);
      await tester.tap(find.text('Güncelle'));
      await _settle(tester);
      expect(backend.appUpdates.storeOpens, 1);
      expect(find.text('Yeni sürüm mevcut'), findsNothing);
      await _unmount(tester);

      // Aynı gün yeniden açılış: pencere yok.
      await _pump(tester, backend, prefs);
      expect(find.text('Yeni sürüm mevcut'), findsNothing);
      await _unmount(tester);
    },
  );

  testWidgets('Sonra ile kapatılır; daha yeni bir sürüm gelince yine sorulur', (
    tester,
  ) async {
    final prefs = await _prefs();
    final backend = _Backend();
    backend.appUpdates.update = const AvailableUpdate(versionCode: 7);
    await _pump(tester, backend, prefs);

    await tester.tap(find.text('Sonra'));
    await _settle(tester);
    expect(find.text('Yeni sürüm mevcut'), findsNothing);
    expect(backend.appUpdates.storeOpens, 0);
    await _unmount(tester);

    backend.appUpdates.update = const AvailableUpdate(versionCode: 8);
    await _pump(tester, backend, prefs);
    expect(find.text('Yeni sürüm mevcut'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('kontrol hata verirse hiçbir şey gösterilmez', (tester) async {
    final prefs = await _prefs();
    final backend = _Backend()..appUpdates.fail = true;
    final router = await _pump(tester, backend, prefs);

    expect(backend.appUpdates.checks, 1);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.textContaining('Güncelleme'), findsNothing);

    router.go('/settings');
    await _settle(tester);
    expect(find.text('Güncelleme mevcut'), findsNothing);
    expect(find.textContaining('hata'), findsNothing);
    await _unmount(tester);
  });

  testWidgets(
    'güncelleme varsa Ayarlar > Hakkında satırı görünür ve mağazayı açar',
    (tester) async {
      final prefs = await _prefs();
      final backend = _Backend();
      backend.appUpdates.update = const AvailableUpdate(versionCode: 7);
      final router = await _pump(tester, backend, prefs);
      await tester.tap(find.text('Sonra'));
      await _settle(tester);

      router.go('/settings');
      await _settle(tester);
      final tile = find.text('Güncelleme mevcut');
      await tester.ensureVisible(tile);
      await _settle(tester, frames: 3);
      await tester.tap(tile);
      await _settle(tester);
      expect(backend.appUpdates.storeOpens, 1);
      await _unmount(tester);
    },
  );
}
