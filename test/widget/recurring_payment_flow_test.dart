import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:harcama_takip/core/firebase/firebase_initialization.dart';
import 'package:harcama_takip/domain/entities/app_user.dart';
import 'package:harcama_takip/domain/entities/credit_card.dart';
import 'package:harcama_takip/main.dart';
import 'package:harcama_takip/presentation/navigation/app_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/fakes.dart';

const _uid = 'u-ayse';

class _Backend extends TestBackend {
  final _auth = FakeAuthRepository(
    initialUser: const AppUser(
      uid: _uid,
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

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text).last;
  await tester.ensureVisible(finder);
  await _settle(tester, frames: 3);
  await tester.tap(finder);
  await _settle(tester);
}

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  testWidgets(
    'otomatik ödeme: karttan oluşturulur, listede görünür, sonlandırılınca geçmiş kalır',
    (tester) async {
      tester.view.physicalSize = const Size(420, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final backend = _Backend();
      final created = DateTime(2026, 1, 1);
      backend.cards.seed([
        CreditCard(
          id: 'c1',
          ownerUid: _uid,
          name: 'Bonus',
          bankName: 'Garanti',
          last4Digits: '4821',
          cutoffDay: 24,
          createdAt: created,
          updatedAt: created,
        ),
      ]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: backend.overrides,
          child: const ExpenseTrackerApp(
            initResult: FirebaseInitResult(isSuccess: true),
          ),
        ),
      );
      await _settle(tester);
      final GoRouter router = ProviderScope.containerOf(
        tester.element(find.byType(ExpenseTrackerApp)),
      ).read(appRouterProvider);

      // Kartlar > Otomatik ödemeler sekmesindeki düğmeyle yeni ödeme.
      router.go('/cards?tab=recurring');
      await _settle(tester);
      expect(find.text('Otomatik ödeme yok'), findsOneWidget);
      await tester.tap(find.byType(FloatingActionButton));
      await _settle(tester);

      expect(find.text('Hangi karttan ödeniyor?'), findsOneWidget);
      expect(find.textContaining('otomatik olarak eklenir'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, '850');
      await tester.enterText(find.byType(TextFormField).at(1), 'İnternet');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await _tapText(tester, 'Otomatik ödemeyi kaydet');

      final payment = backend.recurring.payments.value.single;
      expect(payment.title, 'İnternet');
      expect(payment.amountInCents, 85000);
      expect(payment.cardId, 'c1');
      expect(payment.dayOfMonth, DateTime.now().day);
      final posted = backend.expenses.all.single;
      expect(posted.recurringPaymentId, payment.id);
      expect(posted.paymentMethod, 'credit_card');
      expect(posted.cardId, 'c1');

      // Listede görünür; ayrıntıdan sonlandırılır.
      router.go('/cards?tab=recurring');
      await _settle(tester);
      expect(find.text('İnternet'), findsOneWidget);
      expect(find.textContaining('günü · •••• 4821'), findsOneWidget);
      await tester.tap(find.text('İnternet'));
      await _settle(tester);

      await _tapText(tester, 'Otomatik ödemeyi sonlandır');
      await _tapText(tester, 'Sonlandır');

      final ended = backend.recurring.payments.value.single;
      expect(ended.status, 'cancelled');
      // Bugünün kaydının tarihi geçmiş sayılır (saat dahil) ve korunur.
      expect(find.textContaining('tarihinde sonlandırıldı'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    },
  );
}
