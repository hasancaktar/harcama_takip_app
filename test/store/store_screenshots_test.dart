// Google Play mağaza ekran görüntülerini örnek verilerle üretir.
//
// Normal test çalıştırmasında atlanır. Üretmek için:
//   flutter test test/store/store_screenshots_test.dart --dart-define=STORE_SHOTS=true
// Çıktı: store_listing/screenshots/raw/*.png (1080x1920)
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:harcama_takip/application/services/installment_posting_service.dart';
import 'package:harcama_takip/core/firebase/firebase_initialization.dart';
import 'package:harcama_takip/core/utils/statement_calculator.dart';
import 'package:harcama_takip/domain/entities/app_user.dart';
import 'package:harcama_takip/domain/entities/budget.dart';
import 'package:harcama_takip/domain/entities/credit_card.dart';
import 'package:harcama_takip/domain/entities/expense.dart';
import 'package:harcama_takip/domain/entities/installment_plan.dart';
import 'package:harcama_takip/main.dart';
import 'package:harcama_takip/presentation/navigation/app_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/fakes.dart';

const _run = bool.fromEnvironment('STORE_SHOTS');
const _uid = 'u-ayse';
const _outDir = 'store_listing/screenshots/raw';
// 1080x1920 piksel = 405x720 dp (yaygın 411 dp genişliğe yakın)
const _dpr = 1080 / 405;

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

Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT']!;
  final dir = '$root/bin/cache/artifacts/material_fonts';
  Future<ByteData> read(String name) async =>
      ByteData.sublistView(await File('$dir/$name').readAsBytes());

  final roboto = FontLoader('Roboto');
  for (final f in [
    'roboto-light.ttf',
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
    'roboto-black.ttf',
  ]) {
    roboto.addFont(read(f));
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(read('materialicons-regular.otf'));
  await icons.load();
}

void _seed(_Backend b, DateTime now) {
  DateTime d(int monthsAgo, int day) =>
      DateTime(now.year, now.month - monthsAgo, day, 12);
  final created = d(6, 1);

  final bonus = CreditCard(
    id: 'card-1',
    ownerUid: _uid,
    name: 'Bonus Platinum',
    bankName: 'Garanti BBVA',
    last4Digits: '4821',
    colorHex: '#0F766E',
    limitInCents: 6000000,
    cutoffDay: 24,
    createdAt: created,
    updatedAt: created,
  );
  final world = CreditCard(
    id: 'card-2',
    ownerUid: _uid,
    name: 'World Card',
    bankName: 'Yapı Kredi',
    last4Digits: '1907',
    colorHex: '#1E3A8A',
    limitInCents: 4000000,
    cutoffDay: 8,
    createdAt: created,
    updatedAt: created,
  );
  b.cards.seed([bonus, world]);

  var n = 0;
  Expense e(
    String title,
    double amount,
    String category,
    DateTime date, {
    String method = 'debit_card',
    CreditCard? card,
  }) {
    final period = card == null
        ? StatementCalculator.periodOf(date)
        : StatementCalculator.resolveStatementPeriod(date, card.cutoffDay);
    return Expense(
      id: 'e${n++}',
      ownerUid: _uid,
      visibility: 'personal',
      title: title,
      amountInCents: (amount * 100).round(),
      category: category,
      date: date,
      paymentMethod: card == null ? method : 'credit_card',
      cardId: card?.id,
      cardLast4: card?.last4Digits,
      statementPeriod: period,
      createdBy: _uid,
      createdAt: date,
      updatedAt: date,
    );
  }

  final expenses = <Expense>[];
  // Önceki aylar (raporlar için)
  const monthly = [
    [7850.0, 2450.0, 1380.0, 3100.0],
    [8420.0, 1980.0, 1520.0, 2650.0],
    [7310.0, 2760.0, 1240.0, 4200.0],
    [8990.0, 2210.0, 1610.0, 2980.0],
    [8150.0, 2540.0, 1450.0, 3560.0],
  ];
  for (var m = 5; m >= 1; m--) {
    final v = monthly[5 - m];
    expenses.addAll([
      e('Market alışverişi', v[0], 'market', d(m, 6), card: bonus),
      e('Restoran', v[1], 'restaurant', d(m, 12), card: world),
      e('İstanbulkart dolum', v[2], 'transportation', d(m, 3)),
      e(
        'Elektrik ve doğalgaz',
        v[3],
        'bills',
        d(m, 15),
        method: 'auto_payment',
      ),
      e('Kira', 18000, 'rent', d(m, 1), method: 'bank_transfer'),
    ]);
  }
  // Bu ay
  final day = now.day;
  DateTime t(int back) =>
      DateTime(now.year, now.month, (day - back).clamp(1, 28), 12);
  expenses.addAll([
    e('Kira', 18000, 'rent', t(day - 1), method: 'bank_transfer'),
    e('Migros', 1845.60, 'market', t(0), card: bonus),
    e('Kahve', 145, 'restaurant', t(0), method: 'cash'),
    e('Netflix', 229.99, 'subscription', t(1), card: world),
    e('Akşam yemeği', 1260, 'restaurant', t(2), card: bonus),
    e('Eczane', 384.50, 'health', t(3), method: 'debit_card'),
    e('Elektrik faturası', 1120.40, 'bills', t(4), method: 'auto_payment'),
    e('Benzin', 2150, 'transportation', t(5), card: bonus),
    e('A101', 642.75, 'market', t(6), method: 'debit_card'),
    e('Sinema', 520, 'entertainment', t(7), card: world),
    e('Spotify', 99.99, 'subscription', t(8), card: world),
    e('Kitap', 310, 'education', t(9), card: bonus),
  ]);

  InstallmentPlan plan(
    String id,
    String title,
    double total,
    int count,
    String category,
    DateTime start,
    CreditCard card,
  ) {
    final cents = (total * 100).round();
    final each = cents ~/ count;
    final list = List<int>.generate(
      count,
      (i) => i == 0 ? cents - each * (count - 1) : each,
    );
    return InstallmentPlan(
      id: id,
      ownerUid: _uid,
      visibility: 'personal',
      title: title,
      totalAmountInCents: cents,
      totalInstallments: count,
      cardId: card.id,
      cardLast4: card.last4Digits,
      category: category,
      startDate: start,
      installmentSchedule: StatementCalculator.generateSchedule(
        startDate: start,
        cutoffDay: card.cutoffDay,
        totalInstallments: count,
        installmentCentsList: list,
      ),
      createdAt: start,
      updatedAt: start,
    );
  }

  final plans = <InstallmentPlan>[];
  for (final p in [
    plan('p1', 'Telefon', 48000, 12, 'shopping', d(4, 10), bonus),
    plan('p2', 'Çamaşır makinesi', 21600, 6, 'home', d(2, 18), world),
    plan('p3', 'Uçak bileti', 7500, 3, 'travel', d(1, 5), bonus),
  ]) {
    final r = InstallmentPostingService.applyAllPostings(
      p,
      now: p.startDate,
      actorUid: _uid,
    );
    plans.add(r.plan);
    expenses.addAll(r.postings);
  }
  b.installments.plans.value = plans;
  b.expenses.seed(expenses);

  final period = StatementCalculator.periodOf(now);
  b.budgets.budgets.value = [
    Budget(
      id: Budget.idFor(ownerUid: _uid, period: period),
      ownerUid: _uid,
      visibility: 'personal',
      period: period,
      totalBudgetInCents: 4500000,
      categoryBudgetsInCents: const {
        'market': 900000,
        'restaurant': 300000,
        'transportation': 250000,
        'entertainment': 150000,
      },
      createdAt: created,
      updatedAt: created,
    ),
  ];
}

Future<void> _settle(WidgetTester tester, {int frames = 20}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _shot(WidgetTester tester, GlobalKey key, String name) async {
  await _settle(tester);
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: _dpr);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$_outDir/$name.png').writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await _loadFonts();
    Directory(_outDir).createSync(recursive: true);
  });

  testWidgets('mağaza ekran görüntüleri', (tester) async {
    debugDisableShadows = false;
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = _dpr;
    addTearDown(tester.view.reset);

    final backend = _Backend();
    _seed(backend, DateTime.now());
    final key = GlobalKey();

    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: backend.overrides,
          child: const ExpenseTrackerApp(
            initResult: FirebaseInitResult(isSuccess: true),
          ),
        ),
      ),
    );
    await _settle(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ExpenseTrackerApp)),
    );
    final GoRouter router = container.read(appRouterProvider);

    Future<void> go(String route, String name) async {
      router.go(route);
      await _shot(tester, key, name);
    }

    await go('/dashboard', '01_dashboard');
    await go('/expenses', '02_expenses');
    await go('/cards', '03_cards');
    await tester.tap(find.text('Taksit planları'));
    await _shot(tester, key, '04_installments');
    await go('/reports', '05_reports');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -420));
    await _shot(tester, key, '05b_reports_categories');
    await go('/budgets', '06_budgets');
    await go('/expenses/new', '07_new_expense');

    debugDisableShadows = true;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }, skip: !_run);
}
