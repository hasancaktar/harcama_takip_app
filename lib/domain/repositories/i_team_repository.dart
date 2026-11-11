import '../entities/team.dart';
import '../entities/team_member.dart';

abstract class ITeamRepository {
  Stream<List<Team>> watchUserTeams(String uid);
  Stream<List<TeamMember>> watchTeamMembers(String teamId);
  Future<void> createTeam(Team team, TeamMember ownerMember);
  Future<void> updateTeam(Team team);
  Future<void> inviteMember({
    required String teamId,
    required String teamName,
    required String email,
    required String invitedByUid,
    String role = 'member',
  });
  Future<void> acceptInvite(String inviteCode, String uid, String displayName, String email);
  Future<void> removeMember(String teamId, String memberUid);
  Future<void> leaveTeam(String teamId, String uid);
}
