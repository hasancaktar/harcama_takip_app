import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/budget.dart';
import 'auth_providers.dart';
import 'expense_providers.dart';
import 'repository_providers.dart';
import 'team_providers.dart';

final currentBudgetProvider = StreamProvider<Budget?>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value(null);

  final period = ref.watch(selectedPeriodProvider);
  final activeTeam = ref.watch(activeTeamProvider);
  final budgetRepo = ref.watch(budgetRepositoryProvider);

  return budgetRepo.watchBudget(
    period: period,
    ownerUid: uid,
    teamId: activeTeam?.id,
  );
});
