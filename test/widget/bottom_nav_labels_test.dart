import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harcama_takip/core/firebase/firebase_initialization.dart';
import 'package:harcama_takip/domain/entities/app_user.dart';
import 'package:harcama_takip/main.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/fakes.dart';
import '../helpers/fonts.dart';

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

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    ProviderScope(
      overrides: _Backend().overrides,
      child: const ExpenseTrackerApp(
        initResult: FirebaseInitResult(isSuccess: true),
      ),
    ),
  );
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

double _labelHeight(WidgetTester tester, String label) => tester
    .getSize(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      ),
    )
    .height;

double _labelFontSize(WidgetTester tester, String label) => tester
    .widget<Text>(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      ),
    )
    .style!
    .fontSize!;

Future<void> _expectSingleLineLabels(
  WidgetTester tester, {
  required double minFontSize,
  double maxFontSize = 12,
}) async {
  expect(
    _labelFontSize(tester, 'Özet'),
    inInclusiveRange(minFontSize, maxFontSize),
    reason: 'etiketler gereksiz küçültülmemeli',
  );
  final oneLine = _labelHeight(tester, 'Özet');
  for (final label in ['Harcamalar', 'Kartlar', 'Raporlar', 'Ayarlar']) {
    expect(
      _labelHeight(tester, label),
      oneLine,
      reason: '"$label" tek satırda kalmalı',
    );
  }
  // Seçili sekme kalın yazılır ve daha geniştir.
  await tester.tap(find.text('Harcamalar'));
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(_labelHeight(tester, 'Harcamalar'), oneLine);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await loadRealFonts();
  });

  testWidgets('geniş ekranda etiketler tasarlanan boyutta (12) kalır', (
    tester,
  ) async {
    await _pump(tester, width: 412);
    await _expectSingleLineLabels(tester, minFontSize: 12);
  });

  for (final width in [320.0, 360.0]) {
    testWidgets(
      'alt menü etiketleri $width dp genişlikte tek satırda ve okunur kalır',
      (tester) async {
        await _pump(tester, width: width);
        await _expectSingleLineLabels(tester, minFontSize: 9.5);
      },
    );
  }

  testWidgets('büyük yazı boyutunda da etiketler tek satırda kalır', (
    tester,
  ) async {
    await _pump(tester, width: 360, textScale: 1.5);
    await _expectSingleLineLabels(tester, minFontSize: 7);
  });
}
