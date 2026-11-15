import 'package:flutter/foundation.dart';

import '../../core/utils/json_parsers.dart';

@immutable
class TeamMember {
  final String uid;
  final String teamId;
  final String displayName;
  final String email;
  final String role; // 'owner' | 'admin' | 'member'
  final String status; // 'accepted' | 'left' | 'removed'
  final DateTime joinedAt;
  final String invitedBy;
  final String? inviteId;

  const TeamMember({
    required this.uid,
    required this.teamId,
    required this.displayName,
    required this.email,
    required this.role,
    this.status = 'accepted',
    required this.joinedAt,
    required this.invitedBy,
    this.inviteId,
  });

  bool get isOwner => role == 'owner';
  bool get isAdminOrOwner => role == 'owner' || role == 'admin';
  String get label => displayName.isNotEmpty ? displayName : email;

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'teamId': teamId,
      'displayName': displayName,
      'email': email,
      'role': role,
      'status': status,
      'joinedAt': joinedAt.toIso8601String(),
      'invitedBy': invitedBy,
      if (inviteId != null) 'inviteId': inviteId,
    };
  }

  factory TeamMember.fromMap(Map<String, dynamic> map) {
    return TeamMember(
      uid: JsonParsers.string(map['uid']),
      teamId: JsonParsers.string(map['teamId']),
      displayName: JsonParsers.string(map['displayName']),
      email: JsonParsers.string(map['email']),
      role: JsonParsers.string(map['role'], fallback: 'member'),
      status: JsonParsers.string(map['status'], fallback: 'accepted'),
      joinedAt: JsonParsers.date(map['joinedAt'], fallback: DateTime.now()),
      invitedBy: JsonParsers.string(map['invitedBy']),
      inviteId: JsonParsers.stringOrNull(map['inviteId']),
    );
  }
}
