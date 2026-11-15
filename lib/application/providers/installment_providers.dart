import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/installment_plan.dart';
import 'auth_providers.dart';
import 'repository_providers.dart';
import 'team_providers.dart';

/// Aktif çalışma alanının taksit planları (bireysel modda kişisel planlar, takım modunda takım planları).
final installmentPlansProvider = StreamProvider<List<InstallmentPlan>>((
  ref,
) async* {
  final uid = ref.watch(currentUserIdProvider);
  final repo = ref.watch(installmentRepositoryProvider);
  final teamIdFuture = ref.watch(
    workspaceProvider.selectAsync((w) => w.teamId),
  );
  if (uid == null) {
    yield const [];
    return;
  }
  final teamId = await teamIdFuture;
  if (teamId == null) {
    yield* repo
        .watchOwnPlans(uid)
        .map(
          (plans) => plans.where((p) => p.visibility == 'personal').toList(),
        );
  } else {
    yield* repo.watchTeamPlans(teamId);
  }
});

final installmentPlanByIdProvider = StreamProvider.autoDispose
    .family<InstallmentPlan?, String>((ref, id) {
      return ref.watch(installmentRepositoryProvider).watchPlan(id);
    });

/// Oturum başına bir kez (ve yenile hareketinde) vadesi gelen taksitleri işler.
final installmentSyncProvider = FutureProvider<int>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return 0;
  return ref.watch(installmentPostingServiceProvider).syncOwnPlans(uid);
});
