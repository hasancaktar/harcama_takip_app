import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/statement_calculator.dart';
import '../../domain/entities/expense.dart';
import 'auth_providers.dart';
import 'repository_providers.dart';
import 'team_providers.dart';

/// Seçili dönem (`YYYY-MM`). Varsayılan: içinde bulunulan ay.
final selectedPeriodProvider = StateProvider<String>(
  (ref) => StatementCalculator.periodOf(DateTime.now()),
);

/// Takım modunda liste filtresi: tüm takım harcamaları veya yalnızca kullanıcının ekledikleri.
enum TeamExpenseFilter { all, mine }

final teamExpenseFilterProvider = StateProvider<TeamExpenseFilter>(
  (ref) => TeamExpenseFilter.all,
);

/// Aktif çalışma alanının seçili dönemdeki tüm harcamaları.
final periodExpensesProvider = StreamProvider<List<Expense>>((ref) async* {
  final uid = ref.watch(currentUserIdProvider);
  final period = ref.watch(selectedPeriodProvider);
  final repo = ref.watch(expenseRepositoryProvider);
  final teamIdFuture = ref.watch(
    workspaceProvider.selectAsync((w) => w.teamId),
  );
  if (uid == null) {
    yield const [];
    return;
  }
  final teamId = await teamIdFuture;
  yield* teamId == null
      ? repo.watchPersonalExpenses(uid: uid, periods: [period])
      : repo.watchTeamExpenses(teamId: teamId, periods: [period]);
});

/// Liste ve özetlerde gösterilen harcamalar (takım filtresi uygulanmış).
final visibleExpensesProvider = Provider<AsyncValue<List<Expense>>>((ref) {
  final expenses = ref.watch(periodExpensesProvider);
  final filter = ref.watch(teamExpenseFilterProvider);
  final isTeam = ref.watch(activeTeamProvider) != null;
  final uid = ref.watch(currentUserIdProvider);
  if (!isTeam || filter == TeamExpenseFilter.all) return expenses;
  return expenses.whenData(
    (list) => list.where((e) => e.ownerUid == uid).toList(),
  );
});

final expenseByIdProvider = StreamProvider.autoDispose.family<Expense?, String>(
  (ref, id) {
    return ref.watch(expenseRepositoryProvider).watchExpense(id);
  },
);

/// Seçili döneme kadar son 6 dönemin toplamları (trend grafiği için).
final expenseTrendProvider = StreamProvider<List<PeriodTotal>>((ref) async* {
  final uid = ref.watch(currentUserIdProvider);
  final period = ref.watch(selectedPeriodProvider);
  final repo = ref.watch(expenseRepositoryProvider);
  final teamIdFuture = ref.watch(
    workspaceProvider.selectAsync((w) => w.teamId),
  );
  if (uid == null) {
    yield const [];
    return;
  }
  final teamId = await teamIdFuture;
  final periods = StatementCalculator.lastPeriods(period, 6);
  final stream = teamId == null
      ? repo.watchPersonalExpenses(uid: uid, periods: periods)
      : repo.watchTeamExpenses(teamId: teamId, periods: periods);
  yield* stream.map((expenses) {
    final totals = {for (final p in periods) p: 0};
    for (final e in expenses) {
      if (totals.containsKey(e.statementPeriod)) {
        totals[e.statementPeriod] =
            totals[e.statementPeriod]! + e.amountInCents;
      }
    }
    return [for (final p in periods) PeriodTotal(p, totals[p]!)];
  });
});

@immutable
class PeriodTotal {
  final String period;
  final int totalCents;
  const PeriodTotal(this.period, this.totalCents);
}

@immutable
class AmountShare {
  final String key;
  final int cents;
  final int count;
  const AmountShare(this.key, this.cents, this.count);

  double ratioOf(int total) => total <= 0 ? 0 : cents / total;
}

/// Bir harcama listesinin özet istatistikleri. Saf hesaplama; birim testi vardır.
@immutable
class ExpenseStats {
  final int totalCents;
  final int count;
  final int creditCardCents;
  final int installmentCents;
  final List<AmountShare> byCategory;
  final List<AmountShare> byPaymentMethod;
  final List<AmountShare> byMember;
  final Expense? largest;

  const ExpenseStats({
    required this.totalCents,
    required this.count,
    required this.creditCardCents,
    required this.installmentCents,
    required this.byCategory,
    required this.byPaymentMethod,
    required this.byMember,
    required this.largest,
  });

  static const empty = ExpenseStats(
    totalCents: 0,
    count: 0,
    creditCardCents: 0,
    installmentCents: 0,
    byCategory: [],
    byPaymentMethod: [],
    byMember: [],
    largest: null,
  );

  int get averageCents => count == 0 ? 0 : totalCents ~/ count;

  int categoryCents(String categoryId) {
    for (final s in byCategory) {
      if (s.key == categoryId) return s.cents;
    }
    return 0;
  }

  factory ExpenseStats.from(List<Expense> expenses) {
    if (expenses.isEmpty) return empty;
    var total = 0;
    var credit = 0;
    var installment = 0;
    Expense? largest;
    final categories = <String, List<int>>{};
    final methods = <String, List<int>>{};
    final members = <String, List<int>>{};

    void add(Map<String, List<int>> map, String key, int cents) {
      final entry = map.putIfAbsent(key, () => [0, 0]);
      entry[0] += cents;
      entry[1] += 1;
    }

    for (final e in expenses) {
      total += e.amountInCents;
      if (e.isCreditCard) credit += e.amountInCents;
      if (e.isInstallment) installment += e.amountInCents;
      if (largest == null || e.amountInCents > largest.amountInCents) {
        largest = e;
      }
      add(categories, e.category, e.amountInCents);
      add(methods, e.paymentMethod, e.amountInCents);
      add(members, e.ownerUid, e.amountInCents);
    }

    List<AmountShare> sorted(Map<String, List<int>> map) {
      final list =
          map.entries
              .map((e) => AmountShare(e.key, e.value[0], e.value[1]))
              .toList()
            ..sort((a, b) => b.cents.compareTo(a.cents));
      return list;
    }

    return ExpenseStats(
      totalCents: total,
      count: expenses.length,
      creditCardCents: credit,
      installmentCents: installment,
      byCategory: sorted(categories),
      byPaymentMethod: sorted(methods),
      byMember: sorted(members),
      largest: largest,
    );
  }
}

/// Görünen (filtrelenmiş) harcamaların istatistikleri.
final visibleStatsProvider = Provider<ExpenseStats>((ref) {
  final expenses = ref.watch(visibleExpensesProvider).value ?? const [];
  return ExpenseStats.from(expenses);
});

/// Çalışma alanının tamamına ait istatistikler (bütçe karşılaştırması bununla yapılır).
final workspaceStatsProvider = Provider<ExpenseStats>((ref) {
  final expenses = ref.watch(periodExpensesProvider).value ?? const [];
  return ExpenseStats.from(expenses);
});
