import 'package:flutter/foundation.dart';

import '../../core/utils/json_parsers.dart';

/// E-posta adresine bağlı takım daveti. Belge kimliği aynı zamanda 8 karakterlik davet kodudur.
@immutable
class TeamInvite {
  final String id;
  final String teamId;
  final String teamName;
  final String invitedEmail;
  final String role;
  final String status; // 'pending' | 'accepted' | 'declined' | 'revoked'
  final String createdBy;
  final String createdByName;
  final DateTime createdAt;
  final DateTime expiresAt;

  const TeamInvite({
    required this.id,
    required this.teamId,
    required this.teamName,
    required this.invitedEmail,
    this.role = 'member',
    this.status = 'pending',
    required this.createdBy,
    this.createdByName = '',
    required this.createdAt,
    required this.expiresAt,
  });

  String get code => id;
  bool isExpired([DateTime? now]) => (now ?? DateTime.now()).isAfter(expiresAt);
  bool isUsable([DateTime? now]) => status == 'pending' && !isExpired(now);

  factory TeamInvite.fromMap(Map<String, dynamic> map) {
    final createdAt = JsonParsers.date(
      map['createdAt'],
      fallback: DateTime.now(),
    );
    return TeamInvite(
      id: JsonParsers.string(
        map['inviteId'],
        fallback: JsonParsers.string(map['id']),
      ),
      teamId: JsonParsers.string(map['teamId']),
      teamName: JsonParsers.string(map['teamName']),
      invitedEmail: JsonParsers.string(map['invitedEmail']),
      role: JsonParsers.string(map['role'], fallback: 'member'),
      status: JsonParsers.string(map['status'], fallback: 'pending'),
      createdBy: JsonParsers.string(map['createdBy']),
      createdByName: JsonParsers.string(map['createdByName']),
      createdAt: createdAt,
      expiresAt: JsonParsers.date(
        map['expiresAt'],
        fallback: createdAt.add(const Duration(days: 7)),
      ),
    );
  }
}
