import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/team.dart';
import '../../domain/entities/team_member.dart';
import '../../domain/repositories/i_team_repository.dart';

class FirestoreTeamRepository implements ITeamRepository {
  final FirebaseFirestore _firestore;

  FirestoreTeamRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _teamsCol =>
      _firestore.collection('teams');

  @override
  Stream<List<Team>> watchUserTeams(String uid) {
    // Kullanıcının üye olduğu veya sahibi olduğu takımları izler
    return _teamsCol
        .where('ownerUid', isEqualTo: uid)
        .where('isArchived', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Team.fromMap(data);
      }).toList();
    });
  }

  @override
  Stream<List<TeamMember>> watchTeamMembers(String teamId) {
    return _teamsCol
        .doc(teamId)
        .collection('members')
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['uid'] = doc.id;
        return TeamMember.fromMap(data);
      }).toList();
    });
  }

  @override
  Future<void> createTeam(Team team, TeamMember ownerMember) async {
    final batch = _firestore.batch();
    final teamRef = _teamsCol.doc(team.id);
    final memberRef = teamRef.collection('members').doc(ownerMember.uid);

    batch.set(teamRef, team.toMap());
    batch.set(memberRef, ownerMember.toMap());
    await batch.commit();
  }

  @override
  Future<void> updateTeam(Team team) async {
    await _teamsCol.doc(team.id).update(team.toMap());
  }

  @override
  Future<void> inviteMember({
    required String teamId,
    required String teamName,
    required String email,
    required String invitedByUid,
    String role = 'member',
  }) async {
    final inviteId = const Uuid().v4().substring(0, 8).toUpperCase();
    final inviteRef = _teamsCol.doc(teamId).collection('invites').doc(inviteId);

    await inviteRef.set({
      'inviteId': inviteId,
      'teamId': teamId,
      'teamName': teamName,
      'invitedEmail': email.trim().toLowerCase(),
      'inviteCode': inviteId,
      'role': role,
      'status': 'pending',
      'createdBy': invitedByUid,
      'createdAt': DateTime.now().toIso8601String(),
      'expiresAt': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
    });
  }

  @override
  Future<void> acceptInvite(
    String inviteCode,
    String uid,
    String displayName,
    String email,
  ) async {
    // Davet kodunu sorgula (collectionGroup)
    final inviteQuery = await _firestore
        .collectionGroup('invites')
        .where('inviteCode', isEqualTo: inviteCode.trim().toUpperCase())
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (inviteQuery.docs.isEmpty) {
      throw Exception('Geçersiz veya süresi dolmuş davet kodu');
    }

    final inviteDoc = inviteQuery.docs.first;
    final inviteData = inviteDoc.data();
    final teamId = inviteData['teamId'] as String;
    final role = inviteData['role'] as String? ?? 'member';

    final batch = _firestore.batch();

    // Üye olarak ekle
    final memberRef = _teamsCol.doc(teamId).collection('members').doc(uid);
    batch.set(memberRef, {
      'uid': uid,
      'teamId': teamId,
      'displayName': displayName,
      'email': email,
      'role': role,
      'status': 'accepted',
      'joinedAt': DateTime.now().toIso8601String(),
      'invitedBy': inviteData['createdBy'],
    });

    // Davet durumunu güncelle
    batch.update(inviteDoc.reference, {'status': 'accepted'});

    // Takım üye sayısını artır
    batch.update(_teamsCol.doc(teamId), {
      'memberCount': FieldValue.increment(1),
    });

    await batch.commit();
  }

  @override
  Future<void> removeMember(String teamId, String memberUid) async {
    await _teamsCol
        .doc(teamId)
        .collection('members')
        .doc(memberUid)
        .update({'status': 'removed'});
    await _teamsCol.doc(teamId).update({
      'memberCount': FieldValue.increment(-1),
    });
  }

  @override
  Future<void> leaveTeam(String teamId, String uid) async {
    await _teamsCol
        .doc(teamId)
        .collection('members')
        .doc(uid)
        .update({'status': 'left'});
    await _teamsCol.doc(teamId).update({
      'memberCount': FieldValue.increment(-1),
    });
  }
}
