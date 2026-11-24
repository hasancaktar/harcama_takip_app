import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:harcama_takip/core/firebase/firebase_initialization.dart';
import 'package:harcama_takip/core/utils/statement_calculator.dart';
import 'package:harcama_takip/domain/entities/app_user.dart';
import 'package:harcama_takip/domain/entities/debit_card.dart';
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

final _t = DateTime(2026, 1, 1);

DebitCard _card(String id, String name, String last4) => DebitCard(
  id: id,
  ownerUid: _uid,
  name: name,
  bankName: 'Ziraat Bankası',
  last4Digits: last4,
  createdAt: _t,
  updatedAt: _t,
);

Future<void> _settle(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  await tester.ensureVisible(finder);
  await _settle(tester, frames: 3);
  await tester.tap(finder);
  await _settle(tester);
}

Future<GoRouter> _pump(WidgetTester tester, TestBackend backend) async {
  tester.view.physicalSize = const Size(420, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: backend.overrides,
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

  testWidgets('Kartlar: kart türü seçilip banka kartı eklenir ve kaldırılır', (
    tester,
  ) async {
    final backend = _Backend();
    final router = await _pump(tester, backend);
    router.go('/cards');
    await _settle(tester);

    expect(find.text('Kartlar'), findsWidgets);
    await _tap(tester, find.text('Kart ekle').first);
    expect(find.text('Kredi kartı'), findsOneWidget);
    await _tap(tester, find.text('Banka kartı'));
    expect(find.text('Yeni banka kartı'), findsOneWidget);
    // Kesim günü, limit gibi kredi kartı alanları yoktur.
    expect(find.text('Hesap kesim günü'), findsNothing);
    expect(find.text('Limit (isteğe bağlı)'), findsNothing);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Bankkart');
    await tester.enterText(fields.at(1), 'Ziraat Bankası');
    await tester.enterText(fields.at(2), '4321');
    await _tap(tester, find.text('Kartı kaydet'));

    final saved = backend.debitCards.all.single;
    expect(saved.name, 'Bankkart');
    expect(saved.last4Digits, '4321');
    expect(find.text('Banka kartları'), findsOneWidget);
    expect(find.text('Bankkart'), findsOneWidget);

    // Kartı aç ve kaldır.
    await _tap(tester, find.text('Bankkart'));
    await _tap(tester, find.byTooltip('Düzenle'));
    await _tap(tester, find.byTooltip('Kartı kaldır'));
    await _tap(tester, find.widgetWithText(FilledButton, 'Kartı kaldır'));
    expect(backend.debitCards.all.single.isActive, isFalse);
    expect(find.text('Bankkart'), findsNothing);
    await _unmount(tester);
  });

  testWidgets(
    'harcama banka kartıyla kaydedilir; kartın aylık toplamında görünür',
    (tester) async {
      final backend = _Backend();
      backend.debitCards.seed([
        _card('d1', 'Bankkart', '4321'),
        _card('d2', 'Garanti Debit', '8765'),
      ]);
      final router = await _pump(tester, backend);
      router.go('/expenses/new');
      await _settle(tester);

      await tester.enterText(find.byType(TextFormField).first, '250');
      await _tap(tester, find.text('Banka Kartı'));
      expect(find.text('Kart seçilmedi'), findsOneWidget);
      await _tap(tester, find.text('Kart seçilmedi'));
      await _tap(tester, find.text('Garanti Debit •••• 8765').last);
      await _tap(tester, find.text('Harcamayı kaydet'));

      final e = backend.expenses.all.single;
      expect(e.paymentMethod, 'debit_card');
      expect(e.cardId, 'd2');
      expect(e.cardLast4, '8765');
      expect(e.statementPeriod, StatementCalculator.periodOf(e.date));

      router.go('/debit-cards/d2');
      await _settle(tester);
      expect(find.text('₺250,00'), findsWidgets);
      expect(find.text('1 işlem'), findsOneWidget);
      expect(find.textContaining('•••• 8765'), findsWidgets);

      // Diğer kartta bu ay harcama yok.
      router.go('/debit-cards/d1');
      await _settle(tester);
      expect(find.text('Bu ay bu kartla harcama yok'), findsOneWidget);
      await _unmount(tester);
    },
  );

  testWidgets('banka kartı eklemeden de banka kartıyla harcama girilir', (
    tester,
  ) async {
    final backend = _Backend();
    final router = await _pump(tester, backend);
    router.go('/expenses/new');
    await _settle(tester);

    await tester.enterText(find.byType(TextFormField).first, '80');
    await _tap(tester, find.text('Banka Kartı'));
    expect(find.text('Banka kartı ekle (isteğe bağlı)'), findsOneWidget);
    await _tap(tester, find.text('Harcamayı kaydet'));

    final e = backend.expenses.all.single;
    expect(e.paymentMethod, 'debit_card');
    expect(e.cardId, isNull);
    expect(e.cardLast4, isNull);
    await _unmount(tester);
  });
}
