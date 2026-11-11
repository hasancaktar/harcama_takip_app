import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/expense.dart';
import 'auth_providers.dart';
import 'repository_providers.dart';
import 'team_providers.dart';

// Seçili Ay / Dönem (Varsayılan: Şu anki YYYY-MM)
final selectedPeriodProvider = StateProvider<String>((ref) {
  final now = DateTime.now();
  final month = now.month.toString().padLeft(2, '0');
  return '${now.year}-$month';
});

// Filtre Türü: 'all' | 'personal' | 'team'
final expenseFilterProvider = StateProvider<String>((ref) => 'all');

final expensesStreamProvider = StreamProvider<List<Expense>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value([]);

  final period = ref.watch(selectedPeriodProvider);
  final activeTeam = ref.watch(activeTeamProvider);
  final filter = ref.watch(expenseFilterProvider);
  final expenseRepo = ref.watch(expenseRepositoryProvider);

  return expenseRepo.watchExpenses(
    ownerUid: uid,
    teamId: activeTeam?.id,
    statementPeriod: period,
    visibility: filter,
  );
});

class MonthlyStats {
  final int totalCents;
  final int personalCents;
  final int teamCents;
  final int creditCardCents;
  final int installmentCents;
  final Map<String, int> categoryTotalsCents;

  const MonthlyStats({
    required this.totalCents,
    required this.personalCents,
    required this.teamCents,
    required this.creditCardCents,
    required this.installmentCents,
    required this.categoryTotalsCents,
  });
}

final monthlyStatsProvider = Provider<MonthlyStats>((ref) {
  final expenses = ref.watch(expensesStreamProvider).value ?? [];
  final uid = ref.watch(currentUserIdProvider);

  int total = 0;
  int personal = 0;
  int team = 0;
  int creditCard = 0;
  int installment = 0;
  final Map<String, int> categoryMap = {};

  for (final exp in expenses) {
    total += exp.amountInCents;

    if (exp.visibility == 'personal' || exp.ownerUid == uid) {
      personal += exp.amountInCents;
    }
    if (exp.visibility == 'team') {
      team += exp.amountInCents;
    }
    if (exp.paymentMethod == 'credit_card') {
      creditCard += exp.amountInCents;
    }
    if (exp.isInstallment) {
      installment += exp.amountInCents;
    }

    categoryMap[exp.category] = (categoryMap[exp.category] ?? 0) + exp.amountInCents;
  }

  return MonthlyStats(
    totalCents: total,
    personalCents: personal,
    teamCents: team,
    creditCardCents: creditCard,
    installmentCents: installment,
    categoryTotalsCents: categoryMap,
  );
});
