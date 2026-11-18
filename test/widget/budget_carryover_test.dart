import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harcama_takip/core/firebase/firebase_initialization.dart';
import 'package:harcama_takip/core/utils/statement_calculator.dart';
import 'package:harcama_takip/domain/entities/app_user.dart';
import 'package:harcama_takip/domain/entities/budget.dart';
import 'package:harcama_takip/domain/entities/team.dart';
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

Budget _budget({
  required String period,
  int total = 1000000,
  String? teamId,
  String owner = _uid,
}) {
  final at = StatementCalculator.periodStart(period);
  return Budget(
    id: Budget.idFor(ownerUid: owner, teamId: teamId, period: period),
    ownerUid: owner,
    teamId: teamId,
    visibility: teamId != null ? 'team' : 'personal',
    period: period,
    totalBudgetInCents: total,
    categoryBudgetsInCents: const {'market': 300000},
    createdAt: at,
    updatedAt: at,
  );
}

Future<void> _open(WidgetTester tester, _Backend backend, String route) async {
  tester.view.physicalSize = const Size(420, 1000);
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
  ProviderScope.containerOf(tester.element(find.byType(ExpenseTrackerApp)))
      .read(appRouterProvider)
      .go(route);
  await _settle(tester);
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  final current = StatementCalculator.periodOf(DateTime.now());
  final previous = StatementCalculator.shiftPeriod(current, -1);

  group('Budget.resolveForPeriod', () {
    String id(String p) => Budget.idFor(ownerUid: _uid, period: p);

    test('o ayın bütçesi varsa o, yoksa önceki en yakın ay devredilir', () {
      final all = [
        _budget(period: '2026-08', total: 1),
        _budget(period: '2026-10', total: 2),
        _budget(period: '2026-12', total: 3),
      ];
      Budget? at(String p) =>
          Budget.resolveForPeriod(all, period: p, canonicalId: id(p));

      expect(at('2026-10')!.totalBudgetInCents, 2);
      expect(at('2026-10')!.isCarriedOverTo('2026-10'), isFalse);
      expect(at('2026-11')!.totalBudgetInCents, 2);
      expect(at('2026-11')!.isCarriedOverTo('2026-11'), isTrue);
      expect(at('2027-03')!.totalBudgetInCents, 3);
      expect(at('2026-07'), isNull, reason: 'ileriki aylar geriye devredilmez');
    });

    test('aynı ayda birden fazla kayıt varsa kanonik kimlik seçilir', () {
      final legacy = Budget(
        id: 'random',
        ownerUid: _uid,
        visibility: 'personal',
        period: '2026-11',
        totalBudgetInCents: 9,
        createdAt: DateTime(2026, 11, 20),
        updatedAt: DateTime(2026, 11, 20),
      );
      final canonical = _budget(period: '2026-11', total: 5);
      expect(
        Budget.resolveForPeriod(
          [legacy, canonical],
          period: '2026-11',
          canonicalId: id('2026-11'),
        )!.totalBudgetInCents,
        5,
      );
    });
  });

  testWidgets(
    'geçen ayın bütçesi bu aya devredilir; kaydedince yalnızca bu ay için yazılır',
    (tester) async {
      final backend = _Backend();
      backend.budgets.budgets.value = [_budget(period: previous)];
      await _open(tester, backend, '/budgets');

      expect(find.textContaining('bütçesi bu aya devredildi'), findsOneWidget);
      expect(find.text('Bu ay için bütçe belirlenmedi'), findsNothing);
      expect(find.text('Bütçeyi kaldır'), findsNothing);
      final total = find.byType(TextFormField).first;
      expect(tester.widget<TextFormField>(total).controller!.text, '10.000');

      await tester.enterText(total, '12.000');
      // Odaklı alan, ekran yeniden çizilince kendini görünür tutmak için geri kaydırır.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.ensureVisible(find.text('Bütçeyi kaydet'));
      await _settle(tester, frames: 4);
      await tester.tap(find.text('Bütçeyi kaydet'));
      await _settle(tester);

      final byPeriod = {
        for (final b in backend.budgets.budgets.value) b.period: b,
      };
      expect(byPeriod[previous]!.totalBudgetInCents, 1000000);
      expect(byPeriod[current]!.totalBudgetInCents, 1200000);
      expect(byPeriod[current]!.categoryBudgetsInCents, {'market': 300000});
      expect(find.textContaining('bütçesi bu aya devredildi'), findsNothing);
      expect(find.text('Bütçeyi kaldır'), findsOneWidget);
      await _unmount(tester);
    },
  );

  testWidgets(
    'takım bütçesini kurucu olmayan üye göremez değiştiremez; yalnızca görür',
    (tester) async {
      final backend = _Backend();
      final now = DateTime.now();
      backend.teams.teams.value = [
        Team(
          id: 't1',
          name: 'Ev',
          ownerUid: 'u-ali',
          memberUids: const ['u-ali', _uid],
          memberCount: 2,
          createdAt: now,
          updatedAt: now,
        ),
      ];
      backend.budgets.budgets.value = [
        _budget(period: current, teamId: 't1', owner: 'u-ali'),
      ];
      await backend.users.ensureProfile(
        uid: _uid,
        email: 'ayse@example.com',
        displayName: 'Ayşe Yılmaz',
      );
      await backend.users.setActiveTeam(_uid, 't1');
      await _open(tester, backend, '/budgets');

      expect(
        find.text('Takım bütçesini yalnızca takımı kuran kişi belirleyebilir.'),
        findsOneWidget,
      );
      expect(find.text('Bütçeyi kaydet'), findsNothing);
      expect(find.text('Bütçeyi kaldır'), findsNothing);
      final total = tester.widget<TextFormField>(
        find.byType(TextFormField).first,
      );
      expect(total.enabled, isFalse);
      expect(total.controller!.text, '10.000');
      await _unmount(tester);
    },
  );
}
