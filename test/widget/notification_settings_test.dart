import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

Future<void> _settle(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

SwitchListTile _switch(WidgetTester tester, String title) =>
    tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, title));

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  testWidgets(
    'REGRESYON: kişisel hatırlatıcı açılıp kaydedilince açık kalır ve kaydedilir',
    (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final backend = _Backend();
      backend.users.writeLatency = const Duration(milliseconds: 300);
      await tester.pumpWidget(
        ProviderScope(
          overrides: backend.overrides,
          child: const ExpenseTrackerApp(
            initResult: FirebaseInitResult(isSuccess: true),
          ),
        ),
      );
      await _settle(tester);
      final router = ProviderScope.containerOf(
        tester.element(find.byType(ExpenseTrackerApp)),
      ).read(appRouterProvider);
      router.go('/settings/notifications');
      await _settle(tester);

      const reminder = 'Kişisel günlük hatırlatıcı';
      const push = 'Duyuru ve hatırlatma bildirimleri';
      expect(_switch(tester, reminder).value, isFalse);

      // Hatırlatıcıyı aç, sunucu bildirimlerini kapat, bir günü kaldır.
      await tester.tap(find.text(reminder));
      await tester.tap(find.text(push));
      await _settle(tester, frames: 4);
      final sunday = find.widgetWithText(FilterChip, 'Paz');
      await tester.ensureVisible(sunday);
      await tester.pump();
      await tester.tap(sunday);
      await tester.pump();
      await tester.ensureVisible(find.text('Kaydet'));
      await tester.tap(find.text('Kaydet'));
      await _settle(tester);

      final saved = await backend.users.getProfile('u-ayse');
      expect(saved!.dailyReminderEnabled, isTrue);
      expect(saved.pushEnabled, isFalse);
      expect(saved.dailyReminderDays, [1, 2, 3, 4, 5, 6]);
      expect(_switch(tester, reminder).value, isTrue);
      expect(_switch(tester, push).value, isFalse);
      expect(find.text('Bildirim tercihleri kaydedildi.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    },
  );
}
