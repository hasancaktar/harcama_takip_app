import '../entities/app_user.dart';
import '../entities/team.dart';
import '../entities/team_invite.dart';
import '../entities/team_member.dart';

abstract class ITeamRepository {
  Stream<List<Team>> watchUserTeams(String uid);
  Stream<Team?> watchTeam(String teamId);
  Stream<List<TeamMember>> watchMembers(String teamId);
  Stream<List<TeamInvite>> watchPendingTeamInvites(String teamId);
  Stream<List<TeamInvite>> watchMyPendingInvites(String email);

  Future<void> createTeam(Team team, TeamMember ownerMember);
  Future<void> updateTeam({
    required String teamId,
    required String name,
    String? description,
    required String colorHex,
  });

  Future<TeamInvite> createInvite({
    required Team team,
    required String email,
    required AppUser invitedBy,
  });
  Future<void> revokeInvite({required String teamId, required String inviteId});
  Future<void> acceptInvite({
    required TeamInvite invite,
    required AppUser user,
  });
  Future<void> declineInvite(TeamInvite invite);

  Future<void> removeMember({
    required String teamId,
    required String memberUid,
  });
  Future<void> leaveTeam({required String teamId, required String uid});

  /// Kullanıcının üyesi olduğu tüm takımlardaki üye kaydında görünen adı günceller.
  Future<void> updateMemberDisplayName({
    required String uid,
    required String displayName,
  });

  /// Takımı arşivler (silmez); üyelerin geçmiş harcamaları korunur.
  Future<void> archiveTeam(String teamId);
}
