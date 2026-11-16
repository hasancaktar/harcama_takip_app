import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/budget.dart';
import 'auth_providers.dart';
import 'expense_providers.dart';
import 'repository_providers.dart';
import 'team_providers.dart';

/// Aktif çalışma alanının seçili dönemdeki bütçesi.
final currentBudgetProvider = StreamProvider<Budget?>((ref) async* {
  final uid = ref.watch(currentUserIdProvider);
  final period = ref.watch(selectedPeriodProvider);
  final repo = ref.watch(budgetRepositoryProvider);
  final teamIdFuture = ref.watch(
    workspaceProvider.selectAsync((w) => w.teamId),
  );
  if (uid == null) {
    yield null;
    return;
  }
  final teamId = await teamIdFuture;
  yield* repo.watchBudget(ownerUid: uid, teamId: teamId, period: period);
});

enum BudgetLevel { safe, warning, critical, exceeded }

/// Bütçe kullanım durumu (saf hesaplama).
@immutable
class BudgetStatus {
  final int limitCents;
  final int spentCents;

  const BudgetStatus({required this.limitCents, required this.spentCents});

  bool get hasLimit => limitCents > 0;
  int get remainingCents => limitCents - spentCents;
  double get ratio => hasLimit ? spentCents / limitCents : 0;

  BudgetLevel get level {
    if (!hasLimit) return BudgetLevel.safe;
    if (spentCents > limitCents) return BudgetLevel.exceeded;
    if (ratio >= 0.9) return BudgetLevel.critical;
    if (ratio >= 0.75) return BudgetLevel.warning;
    return BudgetLevel.safe;
  }
}

final budgetStatusProvider = Provider<BudgetStatus?>((ref) {
  final budget = ref.watch(currentBudgetProvider).valueOrNull;
  if (budget == null || budget.totalBudgetInCents <= 0) return null;
  final stats = ref.watch(workspaceStatsProvider);
  return BudgetStatus(
    limitCents: budget.totalBudgetInCents,
    spentCents: stats.totalCents,
  );
});
