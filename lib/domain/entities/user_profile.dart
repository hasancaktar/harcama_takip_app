import 'package:flutter/foundation.dart';

@immutable
class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final String firstName;
  final String lastName;
  final String? photoUrl;
  final String defaultCurrency;
  final String defaultTimezone;
  final String themeMode; // 'system' | 'light' | 'dark'
  final bool dailyReminderEnabled;
  final int dailyReminderHour; // 0 - 23 (örn: 21)
  final int dailyReminderMinute; // 0 - 59 (örn: 0)
  final List<int> dailyReminderDays; // [1, 2, 3, 4, 5, 6, 7]
  final String? activeTeamId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    this.firstName = '',
    this.lastName = '',
    this.photoUrl,
    this.defaultCurrency = 'TRY',
    this.defaultTimezone = 'Europe/Istanbul',
    this.themeMode = 'system',
    this.dailyReminderEnabled = true,
    this.dailyReminderHour = 21,
    this.dailyReminderMinute = 0,
    this.dailyReminderDays = const [1, 2, 3, 4, 5, 6, 7],
    this.activeTeamId,
    required this.createdAt,
    required this.updatedAt,
  });

  UserProfile copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? firstName,
    String? lastName,
    String? photoUrl,
    String? defaultCurrency,
    String? defaultTimezone,
    String? themeMode,
    bool? dailyReminderEnabled,
    int? dailyReminderHour,
    int? dailyReminderMinute,
    List<int>? dailyReminderDays,
    String? activeTeamId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      photoUrl: photoUrl ?? this.photoUrl,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      defaultTimezone: defaultTimezone ?? this.defaultTimezone,
      themeMode: themeMode ?? this.themeMode,
      dailyReminderEnabled: dailyReminderEnabled ?? this.dailyReminderEnabled,
      dailyReminderHour: dailyReminderHour ?? this.dailyReminderHour,
      dailyReminderMinute: dailyReminderMinute ?? this.dailyReminderMinute,
      dailyReminderDays: dailyReminderDays ?? this.dailyReminderDays,
      activeTeamId: activeTeamId ?? this.activeTeamId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'firstName': firstName,
      'lastName': lastName,
      'photoUrl': photoUrl,
      'defaultCurrency': defaultCurrency,
      'defaultTimezone': defaultTimezone,
      'themeMode': themeMode,
      'dailyReminderEnabled': dailyReminderEnabled,
      'dailyReminderHour': dailyReminderHour,
      'dailyReminderMinute': dailyReminderMinute,
      'dailyReminderDays': dailyReminderDays,
      'activeTeamId': activeTeamId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] as String? ?? '',
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      firstName: map['firstName'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      defaultCurrency: map['defaultCurrency'] as String? ?? 'TRY',
      defaultTimezone: map['defaultTimezone'] as String? ?? 'Europe/Istanbul',
      themeMode: map['themeMode'] as String? ?? 'system',
      dailyReminderEnabled: map['dailyReminderEnabled'] as bool? ?? true,
      dailyReminderHour: map['dailyReminderHour'] as int? ?? 21,
      dailyReminderMinute: map['dailyReminderMinute'] as int? ?? 0,
      dailyReminderDays: List<int>.from(map['dailyReminderDays'] ?? [1, 2, 3, 4, 5, 6, 7]),
      activeTeamId: map['activeTeamId'] as String?,
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt'].toString()) : DateTime.now(),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt'].toString()) : DateTime.now(),
    );
  }
}
