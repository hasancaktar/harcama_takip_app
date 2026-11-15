import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/team.dart';
import '../../domain/entities/team_invite.dart';
import '../../domain/entities/team_member.dart';
import '../../domain/entities/user_profile.dart';
import 'auth_providers.dart';
import 'repository_providers.dart';

/// Kullanıcının üyesi olduğu (sahibi olduğu ve davetle katıldığı) aktif takımlar.
final userTeamsProvider = StreamProvider<List<Team>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(teamRepositoryProvider).watchUserTeams(uid);
});

/// Aktif çalışma alanı: bireysel (team == null) veya bir takım.
@immutable
class Workspace {
  final Team? team;
  final List<Team> teams;

  const Workspace({this.team, this.teams = const []});

  bool get isTeam => team != null;
  String? get teamId => team?.id;
  String get label => team?.name ?? 'Bireysel';
}

/// Profilde saklanan aktif takım seçimini, kullanıcının gerçekten üyesi olduğu
/// takımlarla eşleştirir. Seçilen takımdan ayrılınmışsa bireysel moda düşer.
final workspaceProvider = FutureProvider<Workspace>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return const Workspace();
  final profileFuture = ref.watch(userProfileProvider.future);
  final teamsFuture = ref.watch(userTeamsProvider.future);

  UserProfile? profile;
  List<Team> teams = const [];
  try {
    profile = await profileFuture;
  } catch (_) {}
  try {
    teams = await teamsFuture;
  } catch (_) {}

  final activeId = profile?.activeTeamId;
  Team? active;
  for (final t in teams) {
    if (t.id == activeId) active = t;
  }
  return Workspace(team: active, teams: teams);
});

final activeTeamProvider = Provider<Team?>(
  (ref) => ref.watch(workspaceProvider).value?.team,
);

/// Çalışma alanı seçimini profile kaydeder (cihazlar arası senkron, uygulama yeniden açıldığında korunur).
final workspaceControllerProvider = Provider<WorkspaceController>(
  (ref) => WorkspaceController(ref),
);

class WorkspaceController {
  final Ref _ref;
  WorkspaceController(this._ref);

  Future<void> select(String? teamId) async {
    final uid = _ref.read(currentUserIdProvider);
    if (uid == null) return;
    await _ref.read(userRepositoryProvider).setActiveTeam(uid, teamId);
  }
}

final activeTeamMembersProvider = StreamProvider<List<TeamMember>>((ref) {
  final team = ref.watch(activeTeamProvider);
  if (team == null) return Stream.value(const []);
  return ref.watch(teamRepositoryProvider).watchMembers(team.id);
});

/// Takım modunda harcamayı kimin eklediğini göstermek için uid -> ad eşlemesi.
final memberNamesProvider = Provider<Map<String, String>>((ref) {
  final members = ref.watch(activeTeamMembersProvider).value ?? const [];
  return {for (final m in members) m.uid: m.label};
});

final teamByIdProvider = StreamProvider.autoDispose.family<Team?, String>((
  ref,
  teamId,
) {
  return ref.watch(teamRepositoryProvider).watchTeam(teamId);
});

final teamMembersProvider = StreamProvider.autoDispose
    .family<List<TeamMember>, String>((ref, teamId) {
      return ref.watch(teamRepositoryProvider).watchMembers(teamId);
    });

final teamInvitesProvider = StreamProvider.autoDispose
    .family<List<TeamInvite>, String>((ref, teamId) {
      return ref.watch(teamRepositoryProvider).watchPendingTeamInvites(teamId);
    });

/// Kullanıcının e-posta adresine gönderilmiş bekleyen davetler.
final myPendingInvitesProvider = StreamProvider<List<TeamInvite>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  final email = ref.watch(currentUserProvider)?.email;
  if (uid == null || email == null || email.isEmpty) {
    return Stream.value(const []);
  }
  return ref.watch(teamRepositoryProvider).watchMyPendingInvites(email);
});
