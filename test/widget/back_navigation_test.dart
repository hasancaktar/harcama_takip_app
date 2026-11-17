import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:harcama_takip/core/firebase/firebase_initialization.dart';
import 'package:harcama_takip/domain/entities/app_user.dart';
import 'package:harcama_takip/main.dart';
import 'package:harcama_takip/presentation/navigation/app_router.dart';
import 'package:intl/date_symbol_data_local.dart';

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

Future<void> settle(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<GoRouter> pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 860);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final backend = _Backend();
  await tester.pumpWidget(
    ProviderScope(
      overrides: backend.overrides,
      child: const ExpenseTrackerApp(
        initResult: FirebaseInitResult(isSuccess: true),
      ),
    ),
  );
  await settle(tester);
  final container = ProviderScope.containerOf(
    tester.element(find.byType(ExpenseTrackerApp)),
  );
  return container.read(appRouterProvider);
}

Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  testWidgets(
    'bildirimden yalnız başına açılan yeni harcama: geri tuşu ana sayfaya döner, uygulamayı kapatmaz',
    (tester) async {
      final router = await pumpApp(tester);

      // Bildirime dokunma / derin bağlantı: sayfa yığının tek elemanı olarak açılır.
      router.go('/expenses/new');
      await settle(tester);
      expect(find.text('Yeni harcama'), findsOneWidget);
      // Altına ana sayfa yerleştirildi; AppBar'da geri düğmesi var.
      expect(router.canPop(), isTrue);
      expect(find.byType(BackButton), findsOneWidget);

      // Android geri tuşu
      final handled = await tester.binding.handlePopRoute();
      await settle(tester);
      expect(handled, isTrue, reason: 'geri tuşu uygulamayı kapatmamalı');
      expect(router.state.uri.path, '/dashboard');
      expect(find.text('Yeni harcama'), findsNothing);
      expect(find.text('Merhaba, Ayşe'), findsOneWidget);
      await unmount(tester);
    },
  );

  testWidgets('başka bir sekmenin üstünde açılan sayfa o sekmeye döner', (
    tester,
  ) async {
    final router = await pumpApp(tester);
    router.go('/reports');
    await settle(tester);
    unawaited(router.push('/expenses/new'));
    await settle(tester);

    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(router.state.uri.path, '/reports');
    await unmount(tester);
  });

  testWidgets('yalnız açılan sayfada kaydetme de ana sayfaya döner', (
    tester,
  ) async {
    final router = await pumpApp(tester);
    router.go('/expenses/new');
    await settle(tester);

    await tester.enterText(find.byType(TextFormField).first, '125');
    await tester.ensureVisible(find.text('Nakit'));
    await tester.tap(find.text('Nakit'));
    await tester.pump();
    await tester.ensureVisible(find.text('Harcamayı kaydet'));
    await tester.tap(find.text('Harcamayı kaydet'));
    await settle(tester);

    expect(router.state.uri.path, '/dashboard');
    expect(find.text('Merhaba, Ayşe'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets(
    'ana sayfanın kendisi değişmez; geri tuşu orada uygulamayı kapatır',
    (tester) async {
      final router = await pumpApp(tester);
      expect(router.state.uri.path, '/dashboard');
      expect(router.canPop(), isFalse);
      await unmount(tester);
    },
  );
}
