import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:harcama_takip/application/providers/market_providers.dart';
import 'package:harcama_takip/application/providers/settings_providers.dart';
import 'package:harcama_takip/core/firebase/firebase_initialization.dart';
import 'package:harcama_takip/domain/entities/app_user.dart';
import 'package:harcama_takip/domain/entities/market_rates.dart';
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

final _rates = MarketRates(
  quotes: const {
    'USD': MarketQuote(
      symbol: 'USD',
      price: 50.6313,
      changePercent: 0.01,
      currency: 'TRY',
    ),
    'EUR': MarketQuote(
      symbol: 'EUR',
      price: 55.6381,
      changePercent: -0.12,
      currency: 'TRY',
    ),
    'XAUUSD': MarketQuote(
      symbol: 'XAUUSD',
      price: 3555.3,
      changePercent: 0.06,
      currency: 'USD',
    ),
    'BTC': MarketQuote(
      symbol: 'BTC',
      price: 59824.33,
      changePercent: 0.05,
      currency: 'USD',
    ),
  },
  fetchedAt: DateTime(2026, 11, 25, 9, 42),
);

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
  tester.view.physicalSize = const Size(420, 2000);
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

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  testWidgets(
    'Özet ekranının altında piyasa verileri görünür ve 3 dakikada bir yenilenir',
    (tester) async {
      SharedPreferences.setMockInitialValues({'language': 'tr'});
      final prefs = await SharedPreferences.getInstance();
      final backend = _Backend();
      backend.market.rates = _rates;
      await _pump(tester, backend, prefs);

      expect(find.text('Piyasalar'), findsOneWidget);
      expect(find.text('₺50,63'), findsOneWidget);
      expect(find.text('₺55,64'), findsOneWidget);
      expect(find.text(r'$3.555,30'), findsOneWidget);
      expect(find.text(r'$59.824'), findsOneWidget);
      expect(find.text('%0,12'), findsOneWidget);
      expect(find.text('09:42'), findsOneWidget);
      expect(backend.market.calls, 1);

      await tester.pump(marketRatesRefreshInterval);
      await _settle(tester, frames: 3);
      expect(backend.market.calls, 2);
      await _unmount(tester);
    },
  );

  testWidgets('servis hata verirse şerit hiç görünmez', (tester) async {
    SharedPreferences.setMockInitialValues({'language': 'tr'});
    final prefs = await SharedPreferences.getInstance();
    final backend = _Backend()..market.fail = true;
    await _pump(tester, backend, prefs);

    expect(backend.market.calls, 1);
    expect(find.text('Piyasalar'), findsNothing);
    expect(find.textContaining('hata'), findsNothing);
    await _unmount(tester);
  });

  testWidgets('Görünüm ayarından kapatılınca şerit kalkar ve istek atılmaz', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'language': 'tr'});
    final prefs = await SharedPreferences.getInstance();
    final backend = _Backend();
    backend.market.rates = _rates;
    final router = await _pump(tester, backend, prefs);
    expect(find.text('Piyasalar'), findsOneWidget);

    unawaited(router.push('/settings/appearance'));
    await _settle(tester);
    final toggle = find.widgetWithText(
      SwitchListTile,
      'Piyasa verilerini göster',
    );
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await _settle(tester);
    expect(prefs.getBool('show_market_rates'), isFalse);

    router.pop();
    await _settle(tester);
    expect(find.text('Piyasalar'), findsNothing);
    final calls = backend.market.calls;
    await tester.pump(marketRatesRefreshInterval * 2);
    await _settle(tester, frames: 3);
    expect(backend.market.calls, calls);
    await _unmount(tester);
  });
}
