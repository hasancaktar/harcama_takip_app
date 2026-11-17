import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:harcama_takip/application/providers/settings_providers.dart';
import 'package:harcama_takip/core/constants/app_constants.dart';
import 'package:harcama_takip/core/firebase/firebase_initialization.dart';
import 'package:harcama_takip/core/l10n/app_locale.dart';
import 'package:harcama_takip/core/utils/statement_calculator.dart';
import 'package:harcama_takip/domain/entities/admin_models.dart';
import 'package:harcama_takip/domain/entities/app_user.dart';
import 'package:harcama_takip/domain/entities/budget.dart';
import 'package:harcama_takip/domain/entities/credit_card.dart';
import 'package:harcama_takip/domain/entities/expense.dart';
import 'package:harcama_takip/domain/entities/installment_plan.dart';
import 'package:harcama_takip/domain/entities/team.dart';
import 'package:harcama_takip/domain/entities/team_invite.dart';
import 'package:harcama_takip/main.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

/// Tüm ekranları farklı ekran boyutlarında ve iki dilde açar; taşma (overflow)
/// ya da çizim hatası veren ekranları raporlar.
///
/// Yeni bir ekran eklendiğinde yolunu [_signedInRoutes] listesine ekleyin.

const _admin = AppUser(
  uid: 'u-admin',
  email: AppConstants.adminEmail,
  displayName: 'Hasan Sancaktar',
  emailVerified: true,
);

class _Screen {
  final String name;
  final Size size;
  const _Screen(this.name, this.size);
}

const _screens = [
  _Screen('küçük telefon dikey', Size(320, 568)),
  _Screen('telefon dikey', Size(390, 844)),
  _Screen('küçük telefon yatay', Size(568, 320)),
  _Screen('telefon yatay', Size(844, 390)),
  _Screen('tablet dikey', Size(768, 1024)),
  _Screen('tablet yatay', Size(1024, 768)),
  _Screen('masaüstü', Size(1440, 900)),
];

const _signedInRoutes = [
  '/dashboard',
  '/expenses',
  '/expenses/new',
  '/expenses/e-market',
  '/expenses/e-taksit',
  '/expenses/e-market/edit',
  '/cards',
  '/cards/new',
  '/cards/card-1',
  '/cards/card-1/edit',
  '/installments/new',
  '/installments/plan-1',
  '/reports',
  '/budgets',
  '/teams',
  '/teams/new',
  '/teams/join',
  '/teams/team-1',
  '/settings',
  '/settings/profile',
  '/settings/notifications',
  '/settings/appearance',
  '/settings/categories',
  '/admin',
  '/admin/send',
  '/admin/daily-reminder',
  '/admin/history',
  '/admin/categories',
  '/admin/users',
  '/admin/logs',
];

const _signedOutRoutes = ['/login', '/register', '/forgot-password'];

class _Backend extends TestBackend {
  final FakeAuthRepository _auth;

  _Backend(AppUser? user) : _auth = FakeAuthRepository(initialUser: user);

  @override
  FakeAuthRepository get auth => _auth;
}

/// Dolu ekranları sınamak için gerçekçi (ve bilerek uzun adlı) veriler.
_Backend _seededBackend() {
  final backend = _Backend(_admin);
  final now = DateTime.now();
  final period = StatementCalculator.periodOf(now);

  Expense expense(
    String id,
    String title,
    int cents,
    String category, {
    String method = 'cash',
    String? cardId,
    bool installment = false,
    String? teamId,
    int daysAgo = 0,
  }) {
    return Expense(
      id: id,
      ownerUid: _admin.uid,
      teamId: teamId,
      visibility: teamId == null ? 'personal' : 'team',
      title: title,
      amountInCents: cents,
      category: category,
      date: now.subtract(Duration(days: daysAgo)),
      paymentMethod: method,
      cardId: cardId,
      cardLast4: cardId == null ? null : '4821',
      isInstallment: installment,
      installmentPlanId: installment ? 'plan-1' : null,
      installmentNumber: installment ? 3 : 1,
      totalInstallments: installment ? 12 : 1,
      statementPeriod: period,
      notes: 'Haftalık alışveriş; fişi saklandı, garanti belgesi çekmecede.',
      createdBy: _admin.uid,
      createdAt: now,
      updatedAt: now,
    );
  }

  backend.expenses.seed([
    expense(
      'e-market',
      'Haftalık market ve manav alışverişi',
      184250,
      'market',
    ),
    expense(
      'e-taksit',
      'Çift kapılı No-Frost buzdolabı ve beş yıllık ek garanti paketi (3/12. taksit)',
      1249999,
      'home',
      method: 'credit_card',
      cardId: 'card-1',
      installment: true,
      daysAgo: 1,
    ),
    expense('e-fatura', 'Elektrik faturası', 96540, 'bills', daysAgo: 2),
    expense(
      'e-takim',
      'Ortak ev kirası',
      2500000,
      'rent',
      method: 'bank_transfer',
      teamId: 'team-1',
      daysAgo: 3,
    ),
    expense('e-bagis', 'Bağış', 50000, 'donation', daysAgo: 4),
    expense('e-ulasim', 'Aylık ulaşım kartı', 150000, 'transport', daysAgo: 5),
  ]);

  backend.cards.seed([
    CreditCard(
      id: 'card-1',
      ownerUid: _admin.uid,
      name: 'Bonus Platinum Troy Yurt İçi Alışveriş Kartı',
      bankName: 'Türkiye Garanti Bankası BBVA',
      last4Digits: '4821',
      limitInCents: 15000000,
      cutoffDay: 31,
      createdAt: now,
      updatedAt: now,
    ),
    CreditCard(
      id: 'card-2',
      ownerUid: _admin.uid,
      name: 'Maximum',
      bankName: 'İş Bankası',
      last4Digits: '0007',
      colorHex: '#7C3AED',
      cutoffDay: 5,
      createdAt: now,
      updatedAt: now,
    ),
  ]);

  final schedule = StatementCalculator.generateSchedule(
    startDate: DateTime(now.year, now.month - 2, 10),
    cutoffDay: 31,
    totalInstallments: 12,
    installmentCentsList: List.filled(12, 1249999),
  );
  backend.installments.plans.value = [
    InstallmentPlan(
      id: 'plan-1',
      ownerUid: _admin.uid,
      visibility: 'personal',
      title: 'Çift kapılı No-Frost buzdolabı ve beş yıllık ek garanti paketi',
      totalAmountInCents: 14999988,
      totalInstallments: 12,
      cardId: 'card-1',
      cardLast4: '4821',
      category: 'home',
      startDate: DateTime(now.year, now.month - 2, 10),
      installmentSchedule: [
        for (final item in schedule)
          item.installmentNumber <= 3 ? item.copyWith(status: 'posted') : item,
      ],
      createdAt: now,
      updatedAt: now,
    ),
  ];

  backend.budgets.budgets.value = [
    Budget(
      id: Budget.idFor(ownerUid: _admin.uid, period: period),
      ownerUid: _admin.uid,
      visibility: 'personal',
      period: period,
      totalBudgetInCents: 3000000,
      categoryBudgetsInCents: const {'market': 150000, 'home': 2000000},
      createdAt: now,
      updatedAt: now,
    ),
  ];

  backend.teams.teams.value = [
    Team(
      id: 'team-1',
      name: 'Sancaktar ailesi ortak ev ve mutfak bütçesi',
      ownerUid: _admin.uid,
      memberUids: [_admin.uid, 'u-2', 'u-3'],
      memberCount: 3,
      createdAt: now,
      updatedAt: now,
    ),
  ];
  backend.teams.myInvites.value = [
    TeamInvite(
      id: 'ABCD2345',
      teamId: 'team-2',
      teamName: 'Yazlık ev arkadaşları',
      invitedEmail: _admin.email,
      createdBy: 'u-9',
      createdByName: 'Abdurrahman Gazi Yılmazoğlu',
      createdAt: now,
      expiresAt: now.add(const Duration(days: 7)),
    ),
  ];

  backend.categories.categories.value = [
    for (var i = 0; i < AppConstants.defaultCategories.length; i++)
      AppConstants.defaultCategories[i].copyWith(
        order: i,
        isActive: i != 3,
        isDeleted: i == 5,
      ),
  ];
  backend.admin.users = [
    for (var i = 0; i < 8; i++)
      AdminUserSummary(
        uid: 'u-$i',
        email: 'kullanici.cok.uzun.bir.eposta.adresi$i@ornek-alan-adi.com.tr',
        displayName: i.isEven ? 'Abdurrahman Gazi Yılmazoğlu $i' : '',
        hasPushToken: i % 3 != 0,
        pushEnabled: i % 4 != 0,
        language: i.isEven ? 'tr' : 'en',
      ),
  ];
  backend.admin.reminder.value = const ReminderConfig(
    enabled: true,
    lastSentDate: '2026-11-16',
  );
  const statuses = [
    'queued',
    'sending',
    'sent',
    'partial',
    'failed',
    'no_recipients',
  ];
  backend.admin.campaigns.value = [
    for (var i = 0; i < statuses.length; i++)
      NotificationCampaign(
        id: 'c-$i',
        type: i.isEven ? 'manual' : 'daily',
        titleTr: 'Planlı bakım çalışması ve yeni sürüm duyurusu',
        bodyTr:
            'Bu gece 02:00-03:00 arasında kısa bir kesinti olacak. '
            'Verileriniz güvende; işlem bitince uygulamayı yeniden açmanız yeterli.',
        target: i.isEven ? 'all' : 'selected',
        targetUids: const ['u-1', 'u-2'],
        status: statuses[i],
        createdByEmail: _admin.email,
        createdAt: now.subtract(Duration(hours: i)),
        finishedAt: now,
        recipientCount: 1240,
        tokenCount: 1893,
        successCount: 1701,
        failureCount: 192,
        optedOutCount: 87,
        error: statuses[i] == 'failed' ? 'messaging/internal-error' : null,
      ),
  ];
  backend.admin.logs.value = [
    for (var i = 0; i < 6; i++)
      AdminLogEntry(
        id: 'l-$i',
        action: 'category.reorder',
        summary: AppConstants.defaultCategories.map((c) => c.nameTr).join(', '),
        adminEmail: _admin.email,
        createdAt: now.subtract(Duration(minutes: i * 7)),
      ),
  ];
  return backend;
}

Future<void> _settle(WidgetTester tester, {int frames = 8}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpApp(
  WidgetTester tester,
  TestBackend backend,
  SharedPreferences prefs,
) async {
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
}

/// Hata ayrıntısından özet satırı ve hataya neden olan bileşenin konumunu çıkarır.
String _describe(FlutterErrorDetails details) {
  final text = details.toString();
  final summary = details.exceptionAsString().split('\n').first;
  final location = RegExp(r'(lib/[\w/]+\.dart:\d+)')
      .firstMatch(text.replaceAll(r'\', '/'))
      ?.group(1);
  return location == null ? summary : '$summary [$location]';
}

/// [routes] içindeki her yolu açar ve çizim hatalarını `ekran · dil · yol: hata` olarak toplar.
Future<List<String>> _visit(
  WidgetTester tester, {
  required TestBackend Function() backend,
  required List<String> routes,
  required _Screen screen,
  required String language,
  double textScale = 1.0,
}) async {
  final problems = <String>[];
  final captured = <FlutterErrorDetails>[];
  final previousHandler = FlutterError.onError;
  FlutterError.onError = captured.add;

  tester.view.physicalSize = screen.size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;

  try {
    SharedPreferences.setMockInitialValues({'language': language});
    final prefs = await SharedPreferences.getInstance();
    await _pumpApp(tester, backend(), prefs);

    for (final route in routes) {
      captured.clear();
      final context = tester.element(find.byType(Scaffold).first);
      GoRouter.of(context).go(route);
      await _settle(tester);
      // Uzun sayfaların alt kısmı da çizilsin.
      final scrollables = find.byType(Scrollable);
      if (scrollables.evaluate().isNotEmpty) {
        await tester.drag(
          scrollables.first,
          const Offset(0, -600),
          warnIfMissed: false,
        );
        await _settle(tester, frames: 3);
      }
      for (final details in captured.toSet()) {
        final label = '${screen.name} · $language · $route';
        final message = '$label: ${_describe(details)}';
        if (!problems.contains(message)) problems.add(message);
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  } finally {
    FlutterError.onError = previousHandler;
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    AppLocale.set(AppLocale.fallback);
    CategoryRegistry.update(const []);
  }
  return problems;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_US');
  });

  for (final language in ['tr', 'en']) {
    for (final screen in _screens) {
      testWidgets(
        'taşma yok: ${screen.name} (${screen.size.width.toInt()}x${screen.size.height.toInt()}) · $language',
        (tester) async {
          final problems = [
            ...await _visit(
              tester,
              backend: _seededBackend,
              routes: _signedInRoutes,
              screen: screen,
              language: language,
            ),
            ...await _visit(
              tester,
              backend: () => _Backend(null),
              routes: _signedOutRoutes,
              screen: screen,
              language: language,
            ),
          ];
          expect(problems, isEmpty, reason: problems.join('\n'));
        },
      );
    }
  }

  testWidgets('boş veriyle de taşma yok (telefon dikey ve yatay)', (
    tester,
  ) async {
    final problems = <String>[];
    for (final screen in [_screens[0], _screens[2]]) {
      for (final language in ['tr', 'en']) {
        problems.addAll(
          await _visit(
            tester,
            backend: () => _Backend(_admin),
            routes: _signedInRoutes,
            screen: screen,
            language: language,
          ),
        );
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  testWidgets('büyük yazı boyutunda (1.3x) taşma yok', (tester) async {
    final problems = <String>[];
    for (final language in ['tr', 'en']) {
      problems.addAll(
        await _visit(
          tester,
          backend: _seededBackend,
          routes: _signedInRoutes,
          screen: const _Screen('telefon dikey 1.3x', Size(360, 740)),
          language: language,
          textScale: 1.3,
        ),
      );
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  testWidgets('ekran döndürülünce sekme ve girilen metin korunur', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'language': 'tr'});
    final prefs = await SharedPreferences.getInstance();
    await _pumpApp(tester, _seededBackend(), prefs);

    // Harcamalar sekmesinde arama yap.
    await tester.tap(find.text('Harcamalar'));
    await _settle(tester);
    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'fatura');
    await _settle(tester);
    expect(find.text('Elektrik faturası'), findsOneWidget);
    expect(find.text('Aylık ulaşım kartı'), findsNothing);

    // Telefonu yatay çevir: gezinme yan raya geçer, arama ve sonuçlar yerinde kalır.
    tester.view.physicalSize = const Size(844, 390);
    await _settle(tester);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    // Alçak ekranda yan raydaki tüm sekmeler görünür ve dokunulabilir kalır.
    for (final label in [
      'Özet',
      'Harcamalar',
      'Kartlar',
      'Raporlar',
      'Ayarlar',
    ]) {
      final rect = tester.getRect(
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.text(label),
        ),
      );
      expect(rect.top, greaterThanOrEqualTo(0), reason: label);
      expect(rect.bottom, lessThanOrEqualTo(390), reason: label);
    }
    expect(find.text('fatura'), findsOneWidget);
    expect(find.text('Elektrik faturası'), findsOneWidget);
    expect(find.text('Aylık ulaşım kartı'), findsNothing);

    // Yeni harcama formunda yazılanlar döndürmede kaybolmaz.
    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).go('/expenses/new');
    await _settle(tester);
    await tester.enterText(find.byType(TextFormField).at(0), '1.250,50');
    await tester.enterText(find.byType(TextFormField).at(1), 'Kulaklık');
    tester.view.physicalSize = const Size(390, 844);
    await _settle(tester);
    expect(find.text('1.250,50'), findsOneWidget);
    expect(find.text('Kulaklık'), findsOneWidget);
    tester.view.physicalSize = const Size(844, 390);
    await _settle(tester);
    expect(find.text('Kulaklık'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
