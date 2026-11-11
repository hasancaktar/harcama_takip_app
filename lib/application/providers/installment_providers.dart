import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/installment_plan.dart';
import 'auth_providers.dart';
import 'repository_providers.dart';
import 'team_providers.dart';

final installmentPlansProvider = StreamProvider<List<InstallmentPlan>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value([]);
  final activeTeam = ref.watch(activeTeamProvider);
  final installmentRepo = ref.watch(installmentRepositoryProvider);

  return installmentRepo.watchInstallmentPlans(
    ownerUid: uid,
    teamId: activeTeam?.id,
    status: 'active',
  );
});
