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
  final String? lastSentTime; // 'HH:MM' (sunucu yazar)

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
    this.lastSentTime,
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
      lastSentTime: JsonParsers.stringOrNull(map['lastSentTime']),
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

  /// Yönetici tarafından pasife alınmış mı?
  final bool disabled;

  const AdminUserSummary({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.hasPushToken,
    required this.pushEnabled,
    required this.language,
    this.disabled = false,
  });

  String get label => displayName.isNotEmpty ? displayName : email;

  /// Sunucunun bu kullanıcıya bildirim gönderip gönderemeyeceği.
  bool get reachable => hasPushToken && pushEnabled && !disabled;

  factory AdminUserSummary.fromMap(Map<String, dynamic> map) {
    final tokens = map['fcmTokens'];
    return AdminUserSummary(
      uid: JsonParsers.string(map['uid']),
      email: JsonParsers.string(map['email']),
      displayName: JsonParsers.string(map['displayName']),
      hasPushToken: tokens is List && tokens.isNotEmpty,
      pushEnabled: JsonParsers.boolValue(map['pushEnabled'], fallback: true),
      language: JsonParsers.string(map['language'], fallback: 'tr'),
      disabled: JsonParsers.boolValue(map['disabled']),
    );
  }

  AdminUserSummary copyWith({bool? disabled}) => AdminUserSummary(
    uid: uid,
    email: email,
    displayName: displayName,
    hasPushToken: hasPushToken,
    pushEnabled: pushEnabled,
    language: language,
    disabled: disabled ?? this.disabled,
  );
}

/// Kullanıcının uygulama içinden gönderdiği öneri / geri bildirim.
@immutable
class FeedbackEntry {
  static const int maxLength = 2000;

  final String id;
  final String uid;
  final String email;
  final String displayName;
  final String message;
  final String appVersion;
  final String platform;
  final String status; // 'new' | 'read'
  final DateTime createdAt;

  const FeedbackEntry({
    required this.id,
    required this.uid,
    required this.email,
    required this.displayName,
    required this.message,
    required this.appVersion,
    required this.platform,
    this.status = 'new',
    required this.createdAt,
  });

  bool get isNew => status == 'new';
  String get senderLabel => displayName.isNotEmpty ? displayName : email;

  FeedbackEntry copyWith({String? status}) => FeedbackEntry(
    id: id,
    uid: uid,
    email: email,
    displayName: displayName,
    message: message,
    appVersion: appVersion,
    platform: platform,
    status: status ?? this.status,
    createdAt: createdAt,
  );

  factory FeedbackEntry.fromMap(Map<String, dynamic> map) => FeedbackEntry(
    id: JsonParsers.string(map['id']),
    uid: JsonParsers.string(map['uid']),
    email: JsonParsers.string(map['email']),
    displayName: JsonParsers.string(map['displayName']),
    message: JsonParsers.string(map['message']),
    appVersion: JsonParsers.string(map['appVersion']),
    platform: JsonParsers.string(map['platform']),
    status: JsonParsers.string(map['status'], fallback: 'new'),
    createdAt: JsonParsers.date(map['createdAt'], fallback: DateTime.now()),
  );
}

/// Bir sürümün "Yenilikler" notları (yönetici yazar, kullanıcı güncellemeden
/// sonra bir kez görür). Her liste öğesi bir madde işaretidir.
@immutable
class ReleaseNotes {
  static final RegExp versionPattern = RegExp(r'^[0-9]+\.[0-9]+\.[0-9]+$');
  static const int maxItems = 20;
  static const int maxItemLength = 200;

  final String version;
  final List<String> addedTr;
  final List<String> addedEn;
  final List<String> removedTr;
  final List<String> removedEn;
  final List<String> fixedTr;
  final List<String> fixedEn;
  final bool published;
  final DateTime? publishedAt;
  final DateTime? updatedAt;

  const ReleaseNotes({
    required this.version,
    this.addedTr = const [],
    this.addedEn = const [],
    this.removedTr = const [],
    this.removedEn = const [],
    this.fixedTr = const [],
    this.fixedEn = const [],
    this.published = false,
    this.publishedAt,
    this.updatedAt,
  });

  /// [languageCode] diline göre maddeler; İngilizcesi boşsa Türkçesi kullanılır.
  List<String> added(String languageCode) =>
      _pick(languageCode, addedTr, addedEn);
  List<String> removed(String languageCode) =>
      _pick(languageCode, removedTr, removedEn);
  List<String> fixed(String languageCode) =>
      _pick(languageCode, fixedTr, fixedEn);

  static List<String> _pick(String code, List<String> tr, List<String> en) =>
      code == 'en' && en.isNotEmpty ? en : tr;

  bool get isEmpty => addedTr.isEmpty && removedTr.isEmpty && fixedTr.isEmpty;

  /// Bu notlar bu kullanıcıya gösterilmeli mi? Yayınlanmış olmalı ve hesap
  /// notlar yayınlanmadan önce açılmış olmalı (yeni kayıt olan güncellemeyi
  /// yaşamadığı için görmez).
  bool shouldShowTo({required DateTime accountCreatedAt}) =>
      published &&
      !isEmpty &&
      publishedAt != null &&
      accountCreatedAt.isBefore(publishedAt!);

  /// Çok satırlı metni maddelere ayırır (boş satırlar ve baştaki "-", "•" atılır).
  static List<String> linesOf(String text) => [
    for (final line in text.split('\n'))
      if (line.trim().replaceFirst(RegExp(r'^[-•*]\s*'), '').isNotEmpty)
        line.trim().replaceFirst(RegExp(r'^[-•*]\s*'), ''),
  ];

  Map<String, dynamic> toMap() => {
    'version': version,
    'addedTr': addedTr,
    'addedEn': addedEn,
    'removedTr': removedTr,
    'removedEn': removedEn,
    'fixedTr': fixedTr,
    'fixedEn': fixedEn,
    'published': published,
  };

  factory ReleaseNotes.fromMap(Map<String, dynamic> map) => ReleaseNotes(
    version: JsonParsers.string(map['version']),
    addedTr: JsonParsers.stringList(map['addedTr']),
    addedEn: JsonParsers.stringList(map['addedEn']),
    removedTr: JsonParsers.stringList(map['removedTr']),
    removedEn: JsonParsers.stringList(map['removedEn']),
    fixedTr: JsonParsers.stringList(map['fixedTr']),
    fixedEn: JsonParsers.stringList(map['fixedEn']),
    published: JsonParsers.boolValue(map['published']),
    publishedAt: JsonParsers.dateOrNull(map['publishedAt']),
    updatedAt: JsonParsers.dateOrNull(map['updatedAt']),
  );

  /// Sürümleri yeniden eskiye sıralar (1.10.0 > 1.9.0).
  static int compareVersions(String a, String b) {
    final pa = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final pb = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (var i = 0; i < 3; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }
}
