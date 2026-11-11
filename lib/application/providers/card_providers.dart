import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/credit_card.dart';
import 'auth_providers.dart';
import 'repository_providers.dart';
import 'team_providers.dart';

final creditCardsProvider = StreamProvider<List<CreditCard>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value([]);
  final activeTeam = ref.watch(activeTeamProvider);
  final cardRepo = ref.watch(cardRepositoryProvider);

  return cardRepo.watchCards(ownerUid: uid, teamId: activeTeam?.id);
});
