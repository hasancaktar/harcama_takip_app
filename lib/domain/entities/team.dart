import 'package:flutter/foundation.dart';

import '../../core/utils/json_parsers.dart';

@immutable
class Team {
  final String id;
  final String name;
  final String? description;
  final String colorHex;
  final String ownerUid;
  final List<String> memberUids;
  final String defaultCurrency;
  final bool isArchived;
  final int memberCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Team({
    required this.id,
    required this.name,
    this.description,
    this.colorHex = '#0F5132',
    required this.ownerUid,
    this.memberUids = const [],
    this.defaultCurrency = 'TRY',
    this.isArchived = false,
    this.memberCount = 1,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'colorHex': colorHex,
      'ownerUid': ownerUid,
      'memberUids': memberUids,
      'defaultCurrency': defaultCurrency,
      'isArchived': isArchived,
      'memberCount': memberCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Team.fromMap(Map<String, dynamic> map) {
    final createdAt = JsonParsers.date(
      map['createdAt'],
      fallback: DateTime.now(),
    );
    final members = JsonParsers.stringList(map['memberUids']);
    return Team(
      id: JsonParsers.string(map['id']),
      name: JsonParsers.string(map['name']),
      description: JsonParsers.stringOrNull(map['description']),
      colorHex: JsonParsers.string(map['colorHex'], fallback: '#0F5132'),
      ownerUid: JsonParsers.string(map['ownerUid']),
      memberUids: members,
      defaultCurrency: JsonParsers.string(
        map['defaultCurrency'],
        fallback: 'TRY',
      ),
      isArchived: JsonParsers.boolValue(map['isArchived']),
      memberCount: members.isNotEmpty
          ? members.length
          : JsonParsers.intValue(map['memberCount'], fallback: 1),
      createdAt: createdAt,
      updatedAt: JsonParsers.date(map['updatedAt'], fallback: createdAt),
    );
  }
}
