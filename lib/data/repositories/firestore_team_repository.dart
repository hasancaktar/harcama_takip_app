import 'package:harcama_takip/core/l10n/app_locale.dart';

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors/error_messages.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/team.dart';
import '../../domain/entities/team_invite.dart';
import '../../domain/entities/team_member.dart';
import '../../domain/repositories/i_team_repository.dart';

class FirestoreTeamRepository implements ITeamRepository {
  final FirebaseFirestore _firestore;
  final Random _random;

  FirestoreTeamRepository({FirebaseFirestore? firestore, Random? random})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _random = random ?? Random.secure();

  static const Duration inviteValidity = Duration(days: 7);
  static const String _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  CollectionReference<Map<String, dynamic>> get _teams =>
      _firestore.collection('teams');
  DocumentReference<Map<String, dynamic>> _team(String id) => _teams.doc(id);
  CollectionReference<Map<String, dynamic>> _members(String teamId) =>
      _team(teamId).collection('members');
  CollectionReference<Map<String, dynamic>> _invites(String teamId) =>
      _team(teamId).collection('invites');

  String get _now => DateTime.now().toIso8601String();

  static Team _teamFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    data['id'] = doc.id;
    return Team.fromMap(data);
  }

  static TeamInvite _inviteFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    data['inviteId'] = doc.id;
    return TeamInvite.fromMap(data);
  }

  String _generateCode() => List.generate(
    8,
    (_) => _codeAlphabet[_random.nextInt(_codeAlphabet.length)],
  ).join();

  @override
  Stream<List<Team>> watchUserTeams(String uid) {
    // Sahibi olunan VE davetle katılınan takımlar (önceki sürüm yalnızca sahip olunanları getiriyordu).
    return _teams.where('memberUids', arrayContains: uid).snapshots().map((s) {
      final teams =
          s.docs.map(_teamFromDoc).where((t) => !t.isArchived).toList()..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
      return teams;
    });
  }

  @override
  Stream<Team?> watchTeam(String teamId) {
    return _team(teamId)
        .snapshots()
        .map((doc) => doc.exists ? _teamFromDoc(doc) : null);
  }

  @override
  Stream<List<TeamMember>> watchMembers(String teamId) {
    return _members(teamId).snapshots().map((s) {
      final members =
          s.docs
              .map((doc) {
                final data = doc.data();
                data['uid'] = doc.id;
                return TeamMember.fromMap(data);
              })
              .where((m) => m.status == 'accepted')
              .toList()
            ..sort((a, b) {
              if (a.isOwner != b.isOwner) return a.isOwner ? -1 : 1;
              return a.joinedAt.compareTo(b.joinedAt);
            });
      return members;
    });
  }

  @override
  Stream<List<TeamInvite>> watchPendingTeamInvites(String teamId) {
    return _invites(teamId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (s) =>
              s.docs.map(_inviteFromDoc).where((i) => i.isUsable()).toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  @override
  Stream<List<TeamInvite>> watchMyPendingInvites(String email) {
    return _firestore
        .collectionGroup('invites')
        .where('invitedEmail', isEqualTo: email.trim().toLowerCase())
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (s) => s.docs.map(_inviteFromDoc).where((i) => i.isUsable()).toList(),
        );
  }

  @override
  Future<void> createTeam(Team team, TeamMember ownerMember) async {
    final batch = _firestore.batch();
    final data = team.toMap()
      ..['memberUids'] = [ownerMember.uid]
      ..['memberCount'] = 1;
    batch.set(_team(team.id), data);
    batch.set(_members(team.id).doc(ownerMember.uid), ownerMember.toMap());
    await batch.commit();
  }

  @override
  Future<void> updateTeam({
    required String teamId,
    required String name,
    String? description,
    required String colorHex,
  }) {
    return _team(teamId).update({
      'name': name,
      'description': description,
      'colorHex': colorHex,
      'updatedAt': _now,
    });
  }

  @override
  Future<TeamInvite> createInvite({
    required Team team,
    required String email,
    required AppUser invitedBy,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail == invitedBy.email.toLowerCase()) {
      throw AppException('Kendinizi davet edemezsiniz.'.tr);
    }

    final existing = await _invites(team.id)
        .where('invitedEmail', isEqualTo: normalizedEmail)
        .where('status', isEqualTo: 'pending')
        .get();
    for (final doc in existing.docs) {
      final invite = _inviteFromDoc(doc);
      if (invite.isUsable()) return invite; // Aynı kişiye ikinci kod üretme.
    }

    final code = _generateCode();
    final now = DateTime.now();
    final expiresAt = now.add(inviteValidity);
    await _invites(team.id).doc(code).set({
      'inviteId': code,
      'teamId': team.id,
      'teamName': team.name,
      'invitedEmail': normalizedEmail,
      'role': 'member',
      'status': 'pending',
      'createdBy': invitedBy.uid,
      'createdByName': invitedBy.displayName,
      'createdAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(expiresAt),
    });
    return TeamInvite(
      id: code,
      teamId: team.id,
      teamName: team.name,
      invitedEmail: normalizedEmail,
      createdBy: invitedBy.uid,
      createdByName: invitedBy.displayName,
      createdAt: now,
      expiresAt: expiresAt,
    );
  }

  @override
  Future<void> revokeInvite({
    required String teamId,
    required String inviteId,
  }) {
    return _invites(teamId).doc(inviteId).update({'status': 'revoked'});
  }

  @override
  Future<void> acceptInvite({
    required TeamInvite invite,
    required AppUser user,
  }) async {
    if (!invite.isUsable()) {
      throw AppException('Bu davetin süresi dolmuş veya geçersiz.'.tr);
    }
    final batch = _firestore.batch();
    batch.set(_members(invite.teamId).doc(user.uid), {
      'uid': user.uid,
      'teamId': invite.teamId,
      'displayName': user.displayName,
      'email': user.email.toLowerCase(),
      'role': 'member',
      'status': 'accepted',
      'joinedAt': _now,
      'invitedBy': invite.createdBy,
      'inviteId': invite.id,
    });
    batch.update(_invites(invite.teamId).doc(invite.id), {
      'status': 'accepted',
      'acceptedBy': user.uid,
      'acceptedAt': FieldValue.serverTimestamp(),
    });
    batch.update(_team(invite.teamId), {
      'memberUids': FieldValue.arrayUnion([user.uid]),
      'memberCount': FieldValue.increment(1),
      'updatedAt': _now,
    });
    await batch.commit();
  }

  @override
  Future<void> declineInvite(TeamInvite invite) {
    return _invites(invite.teamId).doc(invite.id).update({
      'status': 'declined',
      'acceptedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> removeMember({
    required String teamId,
    required String memberUid,
  }) async {
    final batch = _firestore.batch();
    batch.delete(_members(teamId).doc(memberUid));
    batch.update(_team(teamId), {
      'memberUids': FieldValue.arrayRemove([memberUid]),
      'memberCount': FieldValue.increment(-1),
      'updatedAt': _now,
    });
    await batch.commit();
  }

  @override
  Future<void> leaveTeam({required String teamId, required String uid}) =>
      removeMember(teamId: teamId, memberUid: uid);

  @override
  Future<void> archiveTeam(String teamId) {
    return _team(teamId).update({'isArchived': true, 'updatedAt': _now});
  }
}
