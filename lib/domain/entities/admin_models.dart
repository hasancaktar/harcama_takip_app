import 'package:flutter/foundation.dart';

import '../../core/utils/json_parsers.dart';

/// Yönetici tarafından ayarlanan, sunucunun (Cloud Functions) gönderdiği günlük hatırlatma.
@immutable
class ReminderConfig {
  static const String defaultTitleTr = 'Harcama Takip';
  static const String defaultBodyTr =
      'Bugünkü harcamalarınızı girmeyi unutmayın!';
  static const String defaultTitleEn = 'Harcama Takip';
  static const String defaultBodyEn = "Don't forget to log today's expenses!";
  static const String timezone = 'Europe/Istanbul';

  final bool enabled;
  final int hour;
  final int minute;
  final String titleTr;
  final String bodyTr;
  final String titleEn;
  final String bodyEn;
  final String target; // 'all' | 'selected'
  final List<String> targetUids;
  final String? lastSentDate; // 'YYYY-MM-DD' (sunucu yazar)

  const ReminderConfig({
    this.enabled = false,
    this.hour = 21,
    this.minute = 0,
    this.titleTr = defaultTitleTr,
    this.bodyTr = defaultBodyTr,
    this.titleEn = defaultTitleEn,
    this.bodyEn = defaultBodyEn,
    this.target = 'all',
    this.targetUids = const [],
    this.lastSentDate,
  });

  Map<String, dynamic> toMap() => {
    'enabled': enabled,
    'hour': hour,
    'minute': minute,
    'titleTr': titleTr,
    'bodyTr': bodyTr,
    'titleEn': titleEn,
    'bodyEn': bodyEn,
    'target': target,
    'targetUids': targetUids,
    'timezone': timezone,
  };

  factory ReminderConfig.fromMap(Map<String, dynamic> map) {
    return ReminderConfig(
      enabled: JsonParsers.boolValue(map['enabled']),
      hour: JsonParsers.intValue(map['hour'], fallback: 21).clamp(0, 23),
      minute: JsonParsers.intValue(map['minute']).clamp(0, 59),
      titleTr: JsonParsers.string(map['titleTr'], fallback: defaultTitleTr),
      bodyTr: JsonParsers.string(map['bodyTr'], fallback: defaultBodyTr),
      titleEn: JsonParsers.string(map['titleEn'], fallback: defaultTitleEn),
      bodyEn: JsonParsers.string(map['bodyEn'], fallback: defaultBodyEn),
      target: JsonParsers.string(map['target'], fallback: 'all'),
      targetUids: JsonParsers.stringList(map['targetUids']),
      lastSentDate: JsonParsers.stringOrNull(map['lastSentDate']),
    );
  }
}

/// Bir push bildirimi gönderimi (elle veya günlük otomatik) ve sonucu.
@immutable
class NotificationCampaign {
  final String id;
  final String type; // 'manual' | 'daily'
  final String titleTr;
  final String bodyTr;
  final String titleEn;
  final String bodyEn;
  final String target; // 'all' | 'selected'
  final List<String> targetUids;
  final String
  status; // queued | sending | sent | partial | failed | no_recipients
  final String createdByEmail;
  final DateTime createdAt;
  final DateTime? finishedAt;
  final int recipientCount;
  final int tokenCount;
  final int successCount;
  final int failureCount;
  final int optedOutCount;
  final String? error;

  const NotificationCampaign({
    required this.id,
    this.type = 'manual',
    required this.titleTr,
    required this.bodyTr,
    this.titleEn = '',
    this.bodyEn = '',
    this.target = 'all',
    this.targetUids = const [],
    this.status = 'queued',
    this.createdByEmail = '',
    required this.createdAt,
    this.finishedAt,
    this.recipientCount = 0,
    this.tokenCount = 0,
    this.successCount = 0,
    this.failureCount = 0,
    this.optedOutCount = 0,
    this.error,
  });

  bool get isFinished => status != 'queued' && status != 'sending';

  factory NotificationCampaign.fromMap(Map<String, dynamic> map) {
    return NotificationCampaign(
      id: JsonParsers.string(map['id']),
      type: JsonParsers.string(map['type'], fallback: 'manual'),
      titleTr: JsonParsers.string(map['titleTr']),
      bodyTr: JsonParsers.string(map['bodyTr']),
      titleEn: JsonParsers.string(map['titleEn']),
      bodyEn: JsonParsers.string(map['bodyEn']),
      target: JsonParsers.string(map['target'], fallback: 'all'),
      targetUids: JsonParsers.stringList(map['targetUids']),
      status: JsonParsers.string(map['status'], fallback: 'queued'),
      createdByEmail: JsonParsers.string(map['createdByEmail']),
      createdAt: JsonParsers.date(map['createdAt'], fallback: DateTime.now()),
      finishedAt: JsonParsers.dateOrNull(map['finishedAt']),
      recipientCount: JsonParsers.intValue(map['recipientCount']),
      tokenCount: JsonParsers.intValue(map['tokenCount']),
      successCount: JsonParsers.intValue(map['successCount']),
      failureCount: JsonParsers.intValue(map['failureCount']),
      optedOutCount: JsonParsers.intValue(map['optedOutCount']),
      error: JsonParsers.stringOrNull(map['error']),
    );
  }
}

/// Yönetici işlem kaydı (değiştirilemez).
@immutable
class AdminLogEntry {
  final String id;
  final String action;
  final String summary;
  final String adminEmail;
  final DateTime createdAt;

  const AdminLogEntry({
    required this.id,
    required this.action,
    required this.summary,
    required this.adminEmail,
    required this.createdAt,
  });

  factory AdminLogEntry.fromMap(Map<String, dynamic> map) {
    return AdminLogEntry(
      id: JsonParsers.string(map['id']),
      action: JsonParsers.string(map['action']),
      summary: JsonParsers.string(map['summary']),
      adminEmail: JsonParsers.string(map['adminEmail']),
      createdAt: JsonParsers.date(map['createdAt'], fallback: DateTime.now()),
    );
  }
}

/// Yönetim panelindeki kullanıcı listesi satırı.
@immutable
class AdminUserSummary {
  final String uid;
  final String email;
  final String displayName;
  final bool hasPushToken;
  final bool pushEnabled;
  final String language;

  const AdminUserSummary({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.hasPushToken,
    required this.pushEnabled,
    required this.language,
  });

  String get label => displayName.isNotEmpty ? displayName : email;

  /// Sunucunun bu kullanıcıya bildirim gönderip gönderemeyeceği.
  bool get reachable => hasPushToken && pushEnabled;

  factory AdminUserSummary.fromMap(Map<String, dynamic> map) {
    final tokens = map['fcmTokens'];
    return AdminUserSummary(
      uid: JsonParsers.string(map['uid']),
      email: JsonParsers.string(map['email']),
      displayName: JsonParsers.string(map['displayName']),
      hasPushToken: tokens is List && tokens.isNotEmpty,
      pushEnabled: JsonParsers.boolValue(map['pushEnabled'], fallback: true),
      language: JsonParsers.string(map['language'], fallback: 'tr'),
    );
  }
}
