import 'package:flutter/foundation.dart';

import '../../core/utils/json_parsers.dart';

@immutable
class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final String defaultCurrency;
  final String defaultTimezone;
  final bool dailyReminderEnabled;
  final int dailyReminderHour; // 0 - 23
  final int dailyReminderMinute; // 0 - 59
  final List<int> dailyReminderDays; // 1 (Pzt) - 7 (Paz)
  final String? activeTeamId;

  /// Sunucudan gelen duyuru/hatırlatma bildirimlerini almak istiyor mu?
  final bool pushEnabled;
  final String language; // 'tr' | 'en'
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    this.defaultCurrency = 'TRY',
    this.defaultTimezone = 'Europe/Istanbul',
    this.dailyReminderEnabled = false,
    this.dailyReminderHour = 21,
    this.dailyReminderMinute = 0,
    this.dailyReminderDays = const [1, 2, 3, 4, 5, 6, 7],
    this.activeTeamId,
    this.pushEnabled = true,
    this.language = 'tr',
    required this.createdAt,
    required this.updatedAt,
  });

  UserProfile copyWith({
    String? displayName,
    bool? dailyReminderEnabled,
    int? dailyReminderHour,
    int? dailyReminderMinute,
    List<int>? dailyReminderDays,
    String? activeTeamId,
    bool clearActiveTeam = false,
    bool? pushEnabled,
    String? language,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      defaultCurrency: defaultCurrency,
      defaultTimezone: defaultTimezone,
      dailyReminderEnabled: dailyReminderEnabled ?? this.dailyReminderEnabled,
      dailyReminderHour: dailyReminderHour ?? this.dailyReminderHour,
      dailyReminderMinute: dailyReminderMinute ?? this.dailyReminderMinute,
      dailyReminderDays: dailyReminderDays ?? this.dailyReminderDays,
      activeTeamId: clearActiveTeam
          ? null
          : (activeTeamId ?? this.activeTeamId),
      pushEnabled: pushEnabled ?? this.pushEnabled,
      language: language ?? this.language,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'defaultCurrency': defaultCurrency,
      'defaultTimezone': defaultTimezone,
      'dailyReminderEnabled': dailyReminderEnabled,
      'dailyReminderHour': dailyReminderHour,
      'dailyReminderMinute': dailyReminderMinute,
      'dailyReminderDays': dailyReminderDays,
      'activeTeamId': activeTeamId,
      'pushEnabled': pushEnabled,
      'language': language,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    final createdAt = JsonParsers.date(
      map['createdAt'],
      fallback: DateTime.now(),
    );
    final days = JsonParsers.intList(
      map['dailyReminderDays'],
      fallback: const [1, 2, 3, 4, 5, 6, 7],
    ).where((d) => d >= 1 && d <= 7).toSet().toList()..sort();
    return UserProfile(
      uid: JsonParsers.string(map['uid']),
      email: JsonParsers.string(map['email']),
      displayName: JsonParsers.string(map['displayName']),
      defaultCurrency: JsonParsers.string(
        map['defaultCurrency'],
        fallback: 'TRY',
      ),
      defaultTimezone: JsonParsers.string(
        map['defaultTimezone'],
        fallback: 'Europe/Istanbul',
      ),
      dailyReminderEnabled: JsonParsers.boolValue(map['dailyReminderEnabled']),
      dailyReminderHour: JsonParsers.intValue(
        map['dailyReminderHour'],
        fallback: 21,
      ).clamp(0, 23),
      dailyReminderMinute: JsonParsers.intValue(map['dailyReminderMinute'])
          .clamp(0, 59),
      dailyReminderDays: days.isEmpty ? const [1, 2, 3, 4, 5, 6, 7] : days,
      activeTeamId: JsonParsers.stringOrNull(map['activeTeamId']),
      pushEnabled: JsonParsers.boolValue(map['pushEnabled'], fallback: true),
      language: JsonParsers.string(map['language'], fallback: 'tr'),
      createdAt: createdAt,
      updatedAt: JsonParsers.date(map['updatedAt'], fallback: createdAt),
    );
  }
}
