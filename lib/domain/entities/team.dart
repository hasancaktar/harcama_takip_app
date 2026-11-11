import 'package:flutter/foundation.dart';

@immutable
class Team {
  final String id;
  final String name;
  final String? description;
  final String? avatarUrl;
  final String colorHex;
  final String ownerUid;
  final String defaultCurrency;
  final String defaultTimezone;
  final bool isArchived;
  final int memberCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Team({
    required this.id,
    required this.name,
    this.description,
    this.avatarUrl,
    this.colorHex = '#0F5132',
    required this.ownerUid,
    this.defaultCurrency = 'TRY',
    this.defaultTimezone = 'Europe/Istanbul',
    this.isArchived = false,
    this.memberCount = 1,
    required this.createdAt,
    required this.updatedAt,
  });

  Team copyWith({
    String? id,
    String? name,
    String? description,
    String? avatarUrl,
    String? colorHex,
    String? ownerUid,
    String? defaultCurrency,
    String? defaultTimezone,
    bool? isArchived,
    int? memberCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Team(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      colorHex: colorHex ?? this.colorHex,
      ownerUid: ownerUid ?? this.ownerUid,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      defaultTimezone: defaultTimezone ?? this.defaultTimezone,
      isArchived: isArchived ?? this.isArchived,
      memberCount: memberCount ?? this.memberCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'avatarUrl': avatarUrl,
      'colorHex': colorHex,
      'ownerUid': ownerUid,
      'defaultCurrency': defaultCurrency,
      'defaultTimezone': defaultTimezone,
      'isArchived': isArchived,
      'memberCount': memberCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Team.fromMap(Map<String, dynamic> map) {
    return Team(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String?,
      avatarUrl: map['avatarUrl'] as String?,
      colorHex: map['colorHex'] as String? ?? '#0F5132',
      ownerUid: map['ownerUid'] as String? ?? '',
      defaultCurrency: map['defaultCurrency'] as String? ?? 'TRY',
      defaultTimezone: map['defaultTimezone'] as String? ?? 'Europe/Istanbul',
      isArchived: map['isArchived'] as bool? ?? false,
      memberCount: map['memberCount'] as int? ?? 1,
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt'].toString()) : DateTime.now(),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt'].toString()) : DateTime.now(),
    );
  }
}
