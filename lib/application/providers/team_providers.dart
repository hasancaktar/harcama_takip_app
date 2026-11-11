import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/team.dart';
import '../../domain/entities/team_member.dart';
import 'auth_providers.dart';
import 'repository_providers.dart';

final userTeamsProvider = StreamProvider<List<Team>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value([]);
  final teamRepo = ref.watch(teamRepositoryProvider);
  return teamRepo.watchUserTeams(uid);
});

// Kullanıcının seçtiği aktif takım (null ise Bireysel Mod)
final activeTeamIdProvider = StateProvider<String?>((ref) {
  final profile = ref.watch(userProfileProvider).value;
  return profile?.activeTeamId;
});

final activeTeamProvider = Provider<Team?>((ref) {
  final teams = ref.watch(userTeamsProvider).value ?? [];
  final activeId = ref.watch(activeTeamIdProvider);
  if (activeId == null) return null;
  try {
    return teams.firstWhere((t) => t.id == activeId);
  } catch (_) {
    return null;
  }
});

final activeTeamMembersProvider = StreamProvider<List<TeamMember>>((ref) {
  final activeTeam = ref.watch(activeTeamProvider);
  if (activeTeam == null) return Stream.value([]);
  final teamRepo = ref.watch(teamRepositoryProvider);
  return teamRepo.watchTeamMembers(activeTeam.id);
});
