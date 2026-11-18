import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/recurring_payment.dart';
import 'auth_providers.dart';
import 'repository_providers.dart';
import 'team_providers.dart';

/// Aktif çalışma alanının otomatik ödemeleri (bireysel modda kişisel, takım
/// modunda takım ödemeleri).
final recurringPaymentsProvider = StreamProvider<List<RecurringPayment>>((
  ref,
) async* {
  final uid = ref.watch(currentUserIdProvider);
  final repo = ref.watch(recurringPaymentRepositoryProvider);
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
        .watchOwn(uid)
        .map((list) => list.where((p) => p.visibility == 'personal').toList());
  } else {
    yield* repo.watchTeam(teamId);
  }
});

final recurringPaymentByIdProvider = StreamProvider.autoDispose
    .family<RecurringPayment?, String>(
      (ref, id) => ref.watch(recurringPaymentRepositoryProvider).watch(id),
    );

/// Oturum başına bir kez eksik ayların otomatik ödeme kayıtlarını yazar.
final recurringPaymentSyncProvider = FutureProvider<int>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return 0;
  return ref.watch(recurringPaymentServiceProvider).syncOwn(uid);
});
