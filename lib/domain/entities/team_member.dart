import 'package:flutter/foundation.dart';

@immutable
class TeamMember {
  final String uid;
  final String teamId;
  final String displayName;
  final String email;
  final String? photoUrl;
  final String role; // 'owner' | 'admin' | 'member' | 'viewer'
  final String status; // 'invited' | 'accepted' | 'left' | 'removed'
  final DateTime joinedAt;
  final String invitedBy;

  const TeamMember({
    required this.uid,
    required this.teamId,
    required this.displayName,
    required this.email,
    this.photoUrl,
    required this.role,
    this.status = 'accepted',
    required this.joinedAt,
    required this.invitedBy,
  });

  bool get isOwner => role == 'owner';
  bool get isAdminOrOwner => role == 'owner' || role == 'admin';

  TeamMember copyWith({
    String? uid,
    String? teamId,
    String? displayName,
    String? email,
    String? photoUrl,
    String? role,
    String? status,
    DateTime? joinedAt,
    String? invitedBy,
  }) {
    return TeamMember(
      uid: uid ?? this.uid,
      teamId: teamId ?? this.teamId,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      status: status ?? this.status,
      joinedAt: joinedAt ?? this.joinedAt,
      invitedBy: invitedBy ?? this.invitedBy,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'teamId': teamId,
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'role': role,
      'status': status,
      'joinedAt': joinedAt.toIso8601String(),
      'invitedBy': invitedBy,
    };
  }

  factory TeamMember.fromMap(Map<String, dynamic> map) {
    return TeamMember(
      uid: map['uid'] as String? ?? '',
      teamId: map['teamId'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      role: map['role'] as String? ?? 'member',
      status: map['status'] as String? ?? 'accepted',
      joinedAt: map['joinedAt'] != null ? DateTime.parse(map['joinedAt'].toString()) : DateTime.now(),
      invitedBy: map['invitedBy'] as String? ?? '',
    );
  }
}
